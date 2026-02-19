package com.meta.wearable.flutter

import android.app.Application
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.meta.wearable.dat.camera.StreamSession
import com.meta.wearable.dat.camera.startStreamSession
import com.meta.wearable.dat.camera.types.PhotoData
import com.meta.wearable.dat.camera.types.StreamConfiguration
import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.selectors.AutoDeviceSelector
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

class StreamSessionManager(
    private val application: Application,
    private val textureRegistry: TextureRegistry,
    private val scope: CoroutineScope,
    private val streamStateHandler: WearablesStreamHandlers.StreamStateHandler,
    private val videoFrameInfoHandler: WearablesStreamHandlers.VideoFrameInfoHandler,
    private val streamErrorsHandler: WearablesStreamHandlers.StreamErrorsHandler
) {
    private var streamSession: StreamSession? = null
    private var renderer: VideoFrameRenderer? = null
    private var videoJob: Job? = null
    private var stateJob: Job? = null
    private var sessionId: String = ""

    fun startSession(
        videoQuality: VideoQuality,
        frameRate: Int
    ): Map<String, Any> {
        stopSession()

        val textureEntry = textureRegistry.createSurfaceTexture()
        val videoRenderer = VideoFrameRenderer(textureEntry)
        renderer = videoRenderer

        val deviceSelector = AutoDeviceSelector()
        val config = StreamConfiguration(videoQuality = videoQuality, frameRate)
        val session = Wearables.startStreamSession(application, deviceSelector, config)
        streamSession = session
        sessionId = System.currentTimeMillis().toString()

        videoJob = scope.launch(Dispatchers.Main) {
            session.videoStream.collect { videoFrame ->
                videoRenderer.renderFrame(videoFrame)
                videoFrameInfoHandler.eventSink?.success(
                    mapOf(
                        "width" to videoFrame.width,
                        "height" to videoFrame.height,
                        "timestampMs" to System.currentTimeMillis()
                    )
                )
            }
        }

        stateJob = scope.launch(Dispatchers.Main) {
            session.state.collect { state ->
                streamStateHandler.eventSink?.success(
                    Converters.streamSessionStateToString(state)
                )
            }
        }

        return mapOf(
            "sessionId" to sessionId,
            "textureId" to videoRenderer.textureId
        )
    }

    fun stopSession() {
        videoJob?.cancel()
        videoJob = null
        stateJob?.cancel()
        stateJob = null
        streamSession?.close()
        streamSession = null
        renderer?.release()
        renderer = null
    }

    suspend fun capturePhoto(): Map<String, Any>? {
        val session = streamSession ?: return null
        val result = session.capturePhoto()
        var photoResult: Map<String, Any>? = null

        result.onSuccess { photoData ->
            val bitmap = when (photoData) {
                is PhotoData.Bitmap -> photoData.bitmap
                is PhotoData.HEIC -> {
                    val byteArray = ByteArray(photoData.data.remaining())
                    photoData.data.get(byteArray)
                    BitmapFactory.decodeByteArray(byteArray, 0, byteArray.size)
                }
            }
            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                val bytes = stream.toByteArray()
                stream.close()
                photoResult = mapOf(
                    "bytes" to bytes,
                    "width" to bitmap.width,
                    "height" to bitmap.height
                )
            }
        }

        return photoResult
    }

    fun getSessionId(): String = sessionId
}
