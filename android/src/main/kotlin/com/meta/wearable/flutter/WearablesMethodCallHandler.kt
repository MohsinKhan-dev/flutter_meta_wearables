package com.meta.wearable.flutter

import android.app.Activity
import android.app.Application
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.types.DatResult
import com.meta.wearable.dat.core.types.Permission
import com.meta.wearable.dat.core.types.PermissionError
import com.meta.wearable.dat.core.types.PermissionStatus
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class WearablesMethodCallHandler(
    private val scope: CoroutineScope,
    private val streamStateHandler: WearablesStreamHandlers.StreamStateHandler,
    private val videoFrameInfoHandler: WearablesStreamHandlers.VideoFrameInfoHandler,
    private val streamErrorsHandler: WearablesStreamHandlers.StreamErrorsHandler
) : MethodChannel.MethodCallHandler {

    companion object {
        const val PERMISSION_REQUEST_CODE = 48291
    }

    var activity: Activity? = null
    var application: Application? = null
    var textureRegistry: TextureRegistry? = null
    var onInitialized: (() -> Unit)? = null
    var permissionContract: Wearables.RequestPermissionContract? = null

    private var streamSessionManager: StreamSessionManager? = null
    private var mockDeviceKitHandler: MockDeviceKitHandler? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> handleInitialize(result)
            "startRegistration" -> handleStartRegistration(result)
            "startUnregistration" -> handleStartUnregistration(result)
            "checkPermissionStatus" -> handleCheckPermissionStatus(call, result)
            "requestPermission" -> handleRequestPermission(call, result)
            "handleUrl" -> handleUrl(call, result)
            "startStreamSession" -> handleStartStreamSession(call, result)
            "stopStreamSession" -> handleStopStreamSession(result)
            "capturePhoto" -> handleCapturePhoto(result)
            "dispose" -> handleDispose(result)
            "mock_pairRaybanMeta" -> getMockHandler()?.pairRaybanMeta(result)
                ?: result.error("NO_APP", "Application not available", null)
            "mock_unpairDevice" -> {
                val deviceId = call.argument<String>("deviceId")!!
                getMockHandler()?.unpairDevice(deviceId, result)
                    ?: result.error("NO_APP", "Application not available", null)
            }
            "mock_deviceAction" -> {
                val deviceId = call.argument<String>("deviceId")!!
                val action = call.argument<String>("action")!!
                getMockHandler()?.deviceAction(deviceId, action, result)
                    ?: result.error("NO_APP", "Application not available", null)
            }
            "mock_setCameraFeed" -> {
                val deviceId = call.argument<String>("deviceId")!!
                val filePath = call.argument<String>("filePath")!!
                getMockHandler()?.setCameraFeed(deviceId, filePath, result)
                    ?: result.error("NO_APP", "Application not available", null)
            }
            "mock_setCapturedImage" -> {
                val deviceId = call.argument<String>("deviceId")!!
                val filePath = call.argument<String>("filePath")!!
                getMockHandler()?.setCapturedImage(deviceId, filePath, result)
                    ?: result.error("NO_APP", "Application not available", null)
            }
            else -> result.notImplemented()
        }
    }

    private fun handleInitialize(result: MethodChannel.Result) {
        val app = application
        if (app == null) {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }
        try {
            Wearables.initialize(app)
            onInitialized?.invoke()
            result.success(null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize: ${e.message}", null)
        }
    }

    private fun handleStartRegistration(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available for registration", null)
            return
        }
        try {
            Wearables.startRegistration(act)
            result.success(null)
        } catch (e: Exception) {
            result.error("REGISTRATION_ERROR", "Failed to start registration: ${e.message}", null)
        }
    }

    private fun handleStartUnregistration(result: MethodChannel.Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "Activity not available for unregistration", null)
            return
        }
        try {
            Wearables.startUnregistration(act)
            result.success(null)
        } catch (e: Exception) {
            result.error("UNREGISTRATION_ERROR", "Failed to start unregistration: ${e.message}", null)
        }
    }

    private fun handleCheckPermissionStatus(call: MethodCall, result: MethodChannel.Result) {
        val permissionName = call.argument<String>("permission") ?: "camera"
        scope.launch(Dispatchers.Main) {
            try {
                val permission = when (permissionName) {
                    "camera" -> Permission.CAMERA
                    else -> Permission.CAMERA
                }
                val checkResult = Wearables.checkPermissionStatus(permission)
                checkResult.onSuccess { status ->
                    result.success(Converters.permissionStatusToString(status))
                }
                checkResult.onFailure { error, _ ->
                    result.error("PERMISSION_ERROR", "Permission check failed: ${error.description}", null)
                }
            } catch (e: Exception) {
                result.error("PERMISSION_ERROR", "Failed to check permission: ${e.message}", null)
            }
        }
    }

    private fun handleRequestPermission(call: MethodCall, result: MethodChannel.Result) {
        val act = activity
        val contract = permissionContract
        if (act == null || contract == null) {
            result.error("NO_ACTIVITY", "Activity not available for permission request", null)
            return
        }
        if (pendingPermissionResult != null) {
            result.error("IN_PROGRESS", "A permission request is already in progress", null)
            return
        }
        val permissionName = call.argument<String>("permission") ?: "camera"
        val permission = when (permissionName) {
            "camera" -> Permission.CAMERA
            else -> Permission.CAMERA
        }

        // Check if the contract can resolve synchronously (permission already granted/denied)
        val syncResult = contract.getSynchronousResult(act, permission)
        if (syncResult != null) {
            val datResult = syncResult.value
            datResult.onSuccess { status ->
                result.success(Converters.permissionStatusToString(status))
            }
            datResult.onFailure { error, _ ->
                result.error("PERMISSION_ERROR", "Permission request failed: ${error.description}", null)
            }
            return
        }

        // Need to launch the Meta AI app for permission - use startActivityForResult
        pendingPermissionResult = result
        val intent = contract.createIntent(act, permission)
        act.startActivityForResult(intent, PERMISSION_REQUEST_CODE)
    }

    fun handlePermissionResult(datResult: DatResult<PermissionStatus, PermissionError>) {
        val result = pendingPermissionResult ?: return
        pendingPermissionResult = null
        datResult.onSuccess { status ->
            result.success(Converters.permissionStatusToString(status))
        }
        datResult.onFailure { error, _ ->
            result.error("PERMISSION_ERROR", "Permission request failed: ${error.description}", null)
        }
    }

    private fun handleUrl(call: MethodCall, result: MethodChannel.Result) {
        // handleUrl is primarily for iOS deep link callbacks
        result.success(false)
    }

    private fun handleStartStreamSession(call: MethodCall, result: MethodChannel.Result) {
        val app = application
        val registry = textureRegistry
        if (app == null || registry == null) {
            result.error("NO_CONTEXT", "Application or texture registry not available", null)
            return
        }
        try {
            val qualityStr = call.argument<String>("videoQuality") ?: "medium"
            val frameRate = call.argument<Int>("frameRate") ?: 24
            val videoQuality = Converters.videoQualityFromString(qualityStr)

            val manager = StreamSessionManager(
                application = app,
                textureRegistry = registry,
                scope = scope,
                streamStateHandler = streamStateHandler,
                videoFrameInfoHandler = videoFrameInfoHandler,
                streamErrorsHandler = streamErrorsHandler
            )
            streamSessionManager = manager

            val sessionInfo = manager.startSession(videoQuality, frameRate)
            result.success(sessionInfo)
        } catch (e: Exception) {
            result.error("STREAM_ERROR", "Failed to start stream session: ${e.message}", null)
        }
    }

    private fun handleStopStreamSession(result: MethodChannel.Result) {
        try {
            streamSessionManager?.stopSession()
            streamSessionManager = null
            result.success(null)
        } catch (e: Exception) {
            result.error("STREAM_ERROR", "Failed to stop stream session: ${e.message}", null)
        }
    }

    private fun handleCapturePhoto(result: MethodChannel.Result) {
        val manager = streamSessionManager
        if (manager == null) {
            result.error("NO_SESSION", "No active stream session", null)
            return
        }
        scope.launch(Dispatchers.Main) {
            try {
                val photoResult = manager.capturePhoto()
                if (photoResult != null) {
                    result.success(photoResult)
                } else {
                    result.error("CAPTURE_ERROR", "Failed to capture photo", null)
                }
            } catch (e: Exception) {
                result.error("CAPTURE_ERROR", "Photo capture failed: ${e.message}", null)
            }
        }
    }

    private fun handleDispose(result: MethodChannel.Result) {
        streamSessionManager?.stopSession()
        streamSessionManager = null
        mockDeviceKitHandler?.dispose()
        mockDeviceKitHandler = null
        result.success(null)
    }

    private fun getMockHandler(): MockDeviceKitHandler? {
        val app = application ?: return null
        if (mockDeviceKitHandler == null) {
            mockDeviceKitHandler = MockDeviceKitHandler(app)
        }
        return mockDeviceKitHandler
    }

    fun dispose() {
        streamSessionManager?.stopSession()
        streamSessionManager = null
        mockDeviceKitHandler?.dispose()
        mockDeviceKitHandler = null
    }
}
