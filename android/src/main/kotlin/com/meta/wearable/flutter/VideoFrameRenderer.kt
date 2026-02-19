package com.meta.wearable.flutter

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.view.Surface
import com.meta.wearable.dat.camera.types.VideoFrame
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream

class VideoFrameRenderer(
    private val textureEntry: TextureRegistry.SurfaceTextureEntry
) {
    private var surface: Surface? = null
    private var surfaceWidth: Int = 0
    private var surfaceHeight: Int = 0

    val textureId: Long get() = textureEntry.id()

    fun renderFrame(videoFrame: VideoFrame) {
        val width = videoFrame.width
        val height = videoFrame.height

        ensureSurface(width, height)

        val bitmap = videoFrameToBitmap(videoFrame) ?: return
        val canvas: Canvas? = surface?.lockCanvas(null)
        if (canvas != null) {
            canvas.drawBitmap(bitmap, 0f, 0f, null)
            surface?.unlockCanvasAndPost(canvas)
        }
        bitmap.recycle()
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

    private fun videoFrameToBitmap(videoFrame: VideoFrame): Bitmap? {
        val buffer = videoFrame.buffer
        val dataSize = buffer.remaining()
        val byteArray = ByteArray(dataSize)

        val originalPosition = buffer.position()
        buffer.get(byteArray)
        buffer.position(originalPosition)

        val nv21 = convertI420toNV21(byteArray, videoFrame.width, videoFrame.height)
        val image = YuvImage(nv21, ImageFormat.NV21, videoFrame.width, videoFrame.height, null)
        val out = ByteArrayOutputStream()
        image.compressToJpeg(Rect(0, 0, videoFrame.width, videoFrame.height), 80, out)
        val jpegBytes = out.toByteArray()
        out.close()

        return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
    }

    private fun convertI420toNV21(input: ByteArray, width: Int, height: Int): ByteArray {
        val output = ByteArray(input.size)
        val size = width * height
        val quarter = size / 4

        input.copyInto(output, 0, 0, size)

        for (n in 0 until quarter) {
            output[size + n * 2] = input[size + quarter + n] // V first
            output[size + n * 2 + 1] = input[size + n] // U second
        }
        return output
    }

    fun release() {
        surface?.release()
        surface = null
        textureEntry.release()
    }
}
