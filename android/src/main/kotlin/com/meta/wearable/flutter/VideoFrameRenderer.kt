package com.meta.wearable.flutter

import android.graphics.Bitmap
import android.graphics.Canvas
import android.view.Surface
import com.meta.wearable.dat.camera.types.VideoFrame
import io.flutter.view.TextureRegistry

/**
 * Optimized video frame renderer — direct I420→ARGB conversion
 * with reusable buffers. No JPEG round-trip.
 */
class VideoFrameRenderer(
    private val textureEntry: TextureRegistry.SurfaceTextureEntry
) {
    private var surface: Surface? = null
    private var surfaceWidth: Int = 0
    private var surfaceHeight: Int = 0

    // Reusable buffers — allocated once per resolution
    private var argbPixels: IntArray? = null
    private var bitmap: Bitmap? = null
    private var yPlane: ByteArray? = null
    private var uPlane: ByteArray? = null
    private var vPlane: ByteArray? = null
    private var lastPixelCount: Int = 0

    val textureId: Long get() = textureEntry.id()

    fun renderFrame(videoFrame: VideoFrame) {
        val width = videoFrame.width
        val height = videoFrame.height

        ensureSurface(width, height)
        ensureBuffers(width, height)

        convertI420toARGB(videoFrame.buffer, width, height)

        val bmp = bitmap!!
        bmp.setPixels(argbPixels!!, 0, width, 0, 0, width, height)

        val canvas: Canvas? = surface?.lockCanvas(null)
        if (canvas != null) {
            canvas.drawBitmap(bmp, 0f, 0f, null)
            surface?.unlockCanvasAndPost(canvas)
        }
    }

    private fun ensureSurface(width: Int, height: Int) {
        if (surface == null || surfaceWidth != width || surfaceHeight != height) {
            surface?.release()
            val surfaceTexture = textureEntry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(width, height)
            surface = Surface(surfaceTexture)
            surfaceWidth = width
            surfaceHeight = height
        }
    }

    private fun ensureBuffers(width: Int, height: Int) {
        val pixelCount = width * height
        if (pixelCount != lastPixelCount) {
            val chromaSize = pixelCount / 4
            argbPixels = IntArray(pixelCount)
            bitmap?.recycle()
            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            yPlane = ByteArray(pixelCount)
            uPlane = ByteArray(chromaSize)
            vPlane = ByteArray(chromaSize)
            lastPixelCount = pixelCount
        }
    }

    /**
     * Direct I420 to ARGB int conversion.
     *
     * I420 layout: [Y: w*h] [U: w*h/4] [V: w*h/4]
     * Output: 0xAARRGGBB packed int per pixel (for Bitmap.setPixels)
     */
    private fun convertI420toARGB(buffer: java.nio.ByteBuffer, width: Int, height: Int) {
        val frameSize = width * height
        val chromaSize = frameSize / 4
        val chromaWidth = width / 2

        val y = yPlane!!
        val u = uPlane!!
        val v = vPlane!!
        val out = argbPixels!!

        val originalPosition = buffer.position()
        buffer.position(originalPosition)
        buffer.get(y, 0, frameSize)
        buffer.get(u, 0, chromaSize)
        buffer.get(v, 0, chromaSize)
        buffer.position(originalPosition)

        var outIdx = 0
        for (row in 0 until height) {
            val chromaRowOffset = (row shr 1) * chromaWidth
            val yRowOffset = row * width

            for (col in 0 until width) {
                val yVal = y[yRowOffset + col].toInt() and 0xFF
                val chromaIdx = chromaRowOffset + (col shr 1)
                val uVal = (u[chromaIdx].toInt() and 0xFF) - 128
                val vVal = (v[chromaIdx].toInt() and 0xFF) - 128

                var r = yVal + ((359 * vVal) shr 8)
                var g = yVal - ((88 * uVal + 183 * vVal) shr 8)
                var b = yVal + ((454 * uVal) shr 8)

                if (r < 0) r = 0 else if (r > 255) r = 255
                if (g < 0) g = 0 else if (g > 255) g = 255
                if (b < 0) b = 0 else if (b > 255) b = 255

                // 0xAARRGGBB format for Bitmap.setPixels()
                out[outIdx++] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        }
    }

    fun release() {
        surface?.release()
        surface = null
        bitmap?.recycle()
        bitmap = null
        argbPixels = null
        yPlane = null
        uPlane = null
        vPlane = null
        textureEntry.release()
    }
}
