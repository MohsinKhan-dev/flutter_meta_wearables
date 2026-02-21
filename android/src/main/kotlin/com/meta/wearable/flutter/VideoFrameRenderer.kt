package com.meta.wearable.flutter

import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.EGLContext
import android.opengl.EGLDisplay
import android.opengl.EGLSurface
import android.opengl.GLES20
import android.os.Handler
import android.os.HandlerThread
import com.meta.wearable.dat.camera.types.VideoFrame
import io.flutter.view.TextureRegistry
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.CountDownLatch

/**
 * GPU-accelerated video frame renderer using OpenGL ES 2.0
 * on a dedicated HandlerThread (single-thread EGL context affinity).
 *
 * Uploads I420 YUV planes as GL_LUMINANCE textures and converts
 * YUV→RGB in a fragment shader entirely on the GPU.
 */
class VideoFrameRenderer(
    private val textureEntry: TextureRegistry.SurfaceTextureEntry
) {
    companion object {
        private const val VERTEX_SHADER = """
            attribute vec4 aPosition;
            attribute vec2 aTexCoord;
            varying vec2 vTexCoord;
            void main() {
                gl_Position = aPosition;
                vTexCoord = aTexCoord;
            }
        """

        private const val FRAGMENT_SHADER = """
            precision mediump float;
            varying vec2 vTexCoord;
            uniform sampler2D yTex;
            uniform sampler2D uTex;
            uniform sampler2D vTex;
            void main() {
                float y = texture2D(yTex, vTexCoord).r;
                float u = texture2D(uTex, vTexCoord).r - 0.5;
                float v = texture2D(vTex, vTexCoord).r - 0.5;
                float r = y + 1.402 * v;
                float g = y - 0.344136 * u - 0.714136 * v;
                float b = y + 1.772 * u;
                gl_FragColor = vec4(r, g, b, 1.0);
            }
        """

        private val QUAD_VERTICES = floatArrayOf(
            -1f, -1f,
             1f, -1f,
            -1f,  1f,
             1f,  1f
        )

        private val TEX_COORDS = floatArrayOf(
            0f, 1f,
            1f, 1f,
            0f, 0f,
            1f, 0f
        )
    }

    val textureId: Long get() = textureEntry.id()

    // GL state — only touched from glThread
    private var eglDisplay: EGLDisplay = EGL14.EGL_NO_DISPLAY
    private var eglContext: EGLContext = EGL14.EGL_NO_CONTEXT
    private var eglSurface: EGLSurface = EGL14.EGL_NO_SURFACE
    private var eglConfig: EGLConfig? = null
    private var program: Int = 0
    private val yuvTextures = IntArray(3)
    private var glInitialized = false
    private var currentWidth = 0
    private var currentHeight = 0

    // Reusable direct ByteBuffers for texture upload
    private var yBuf: ByteBuffer? = null
    private var uBuf: ByteBuffer? = null
    private var vBuf: ByteBuffer? = null

    private val vertexBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(QUAD_VERTICES.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .put(QUAD_VERTICES)
        .also { it.position(0) }

    private val texCoordBuffer: FloatBuffer = ByteBuffer
        .allocateDirect(TEX_COORDS.size * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .put(TEX_COORDS)
        .also { it.position(0) }

    // Dedicated GL thread — all EGL/GLES calls happen here
    private val glThread = HandlerThread("wearables-gl").apply { start() }
    private val glHandler = Handler(glThread.looper)

    /**
     * Render a frame. Called from any thread — posts work to the GL thread.
     * Blocks until rendering is complete to maintain backpressure.
     */
    fun renderFrame(videoFrame: VideoFrame) {
        val width = videoFrame.width
        val height = videoFrame.height
        val buffer = videoFrame.buffer

        // Copy buffer data on the calling thread (buffer may be recycled after return)
        val frameSize = width * height
        val chromaSize = frameSize / 4
        val totalSize = frameSize + chromaSize + chromaSize

        val yDirect = ensureDirectBuffer(yBuf, frameSize).also { yBuf = it }
        val uDirect = ensureDirectBuffer(uBuf, chromaSize).also { uBuf = it }
        val vDirect = ensureDirectBuffer(vBuf, chromaSize).also { vBuf = it }

        val originalPos = buffer.position()
        val originalLimit = buffer.limit()

        buffer.position(originalPos)
        buffer.limit(originalPos + frameSize)
        yDirect.clear()
        yDirect.put(buffer)
        yDirect.flip()

        buffer.limit(originalPos + frameSize + chromaSize)
        uDirect.clear()
        uDirect.put(buffer)
        uDirect.flip()

        buffer.limit(originalPos + frameSize + chromaSize + chromaSize)
        vDirect.clear()
        vDirect.put(buffer)
        vDirect.flip()

        buffer.position(originalPos)
        buffer.limit(originalLimit)

        val latch = CountDownLatch(1)
        glHandler.post {
            try {
                renderOnGLThread(width, height, yDirect, uDirect, vDirect)
            } finally {
                latch.countDown()
            }
        }
        latch.await()
    }

    private fun renderOnGLThread(
        width: Int, height: Int,
        yData: ByteBuffer, uData: ByteBuffer, vData: ByteBuffer
    ) {
        if (!glInitialized) {
            initEGL(width, height)
            initGL()
            glInitialized = true
            currentWidth = width
            currentHeight = height
        }

        if (width != currentWidth || height != currentHeight) {
            recreateSurface(width, height)
            currentWidth = width
            currentHeight = height
        }

        uploadTextures(width, height, yData, uData, vData)
        drawFrame(width, height)
        EGL14.eglSwapBuffers(eglDisplay, eglSurface)
    }

    // ---- EGL setup ----

    private fun initEGL(width: Int, height: Int) {
        eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        val version = IntArray(2)
        EGL14.eglInitialize(eglDisplay, version, 0, version, 1)

        val attribList = intArrayOf(
            EGL14.EGL_RED_SIZE, 8,
            EGL14.EGL_GREEN_SIZE, 8,
            EGL14.EGL_BLUE_SIZE, 8,
            EGL14.EGL_ALPHA_SIZE, 8,
            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_NONE
        )
        val configs = arrayOfNulls<EGLConfig>(1)
        val numConfigs = IntArray(1)
        EGL14.eglChooseConfig(eglDisplay, attribList, 0, configs, 0, 1, numConfigs, 0)
        eglConfig = configs[0]!!

        val contextAttribs = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
            EGL14.EGL_NONE
        )
        eglContext = EGL14.eglCreateContext(
            eglDisplay, eglConfig!!, EGL14.EGL_NO_CONTEXT, contextAttribs, 0
        )

        createWindowSurface(width, height)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    private fun createWindowSurface(width: Int, height: Int) {
        val surfaceTexture = textureEntry.surfaceTexture()
        surfaceTexture.setDefaultBufferSize(width, height)
        val surfaceAttribs = intArrayOf(EGL14.EGL_NONE)
        eglSurface = EGL14.eglCreateWindowSurface(
            eglDisplay, eglConfig!!, surfaceTexture, surfaceAttribs, 0
        )
    }

    private fun recreateSurface(width: Int, height: Int) {
        EGL14.eglMakeCurrent(
            eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT
        )
        EGL14.eglDestroySurface(eglDisplay, eglSurface)
        createWindowSurface(width, height)
        EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
    }

    // ---- GL setup ----

    private fun initGL() {
        program = createProgram(VERTEX_SHADER, FRAGMENT_SHADER)
        GLES20.glGenTextures(3, yuvTextures, 0)
        for (i in 0..2) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, yuvTextures[i])
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        }
    }

    // ---- Per-frame rendering ----

    private fun uploadTextures(
        width: Int, height: Int,
        yData: ByteBuffer, uData: ByteBuffer, vData: ByteBuffer
    ) {
        val chromaW = width / 2
        val chromaH = height / 2

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, yuvTextures[0])
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE,
            width, height, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, yData
        )

        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, yuvTextures[1])
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE,
            chromaW, chromaH, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, uData
        )

        GLES20.glActiveTexture(GLES20.GL_TEXTURE2)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, yuvTextures[2])
        GLES20.glTexImage2D(
            GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE,
            chromaW, chromaH, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, vData
        )
    }

    private fun drawFrame(width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(program)

        val posHandle = GLES20.glGetAttribLocation(program, "aPosition")
        GLES20.glEnableVertexAttribArray(posHandle)
        GLES20.glVertexAttribPointer(posHandle, 2, GLES20.GL_FLOAT, false, 0, vertexBuffer)

        val texHandle = GLES20.glGetAttribLocation(program, "aTexCoord")
        GLES20.glEnableVertexAttribArray(texHandle)
        GLES20.glVertexAttribPointer(texHandle, 2, GLES20.GL_FLOAT, false, 0, texCoordBuffer)

        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "yTex"), 0)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "uTex"), 1)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(program, "vTex"), 2)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(posHandle)
        GLES20.glDisableVertexAttribArray(texHandle)
    }

    // ---- Shader helpers ----

    private fun createProgram(vertexSrc: String, fragmentSrc: String): Int {
        val vs = loadShader(GLES20.GL_VERTEX_SHADER, vertexSrc)
        val fs = loadShader(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
        val prog = GLES20.glCreateProgram()
        GLES20.glAttachShader(prog, vs)
        GLES20.glAttachShader(prog, fs)
        GLES20.glLinkProgram(prog)
        return prog
    }

    private fun loadShader(type: Int, source: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, source)
        GLES20.glCompileShader(shader)
        return shader
    }

    // ---- Helpers ----

    private fun ensureDirectBuffer(existing: ByteBuffer?, size: Int): ByteBuffer {
        if (existing != null && existing.capacity() >= size) return existing
        return ByteBuffer.allocateDirect(size).order(ByteOrder.nativeOrder())
    }

    // ---- Cleanup ----

    fun release() {
        val latch = CountDownLatch(1)
        glHandler.post {
            try {
                if (glInitialized) {
                    GLES20.glDeleteTextures(3, yuvTextures, 0)
                    GLES20.glDeleteProgram(program)
                    EGL14.eglMakeCurrent(
                        eglDisplay, EGL14.EGL_NO_SURFACE,
                        EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT
                    )
                    EGL14.eglDestroySurface(eglDisplay, eglSurface)
                    EGL14.eglDestroyContext(eglDisplay, eglContext)
                    EGL14.eglTerminate(eglDisplay)
                    glInitialized = false
                }
            } finally {
                latch.countDown()
            }
        }
        latch.await()
        glThread.quitSafely()
        yBuf = null
        uBuf = null
        vBuf = null
        textureEntry.release()
    }
}
