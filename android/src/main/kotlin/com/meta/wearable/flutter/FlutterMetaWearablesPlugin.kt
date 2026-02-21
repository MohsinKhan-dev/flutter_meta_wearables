package com.meta.wearable.flutter

import android.app.Activity
import android.app.Application
import android.content.Intent
import com.meta.wearable.dat.core.Wearables
import com.meta.wearable.dat.core.types.Permission
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class FlutterMetaWearablesPlugin : FlutterPlugin, ActivityAware {

    companion object {
        private const val METHOD_CHANNEL = "com.meta.wearable.flutter/methods"
        private const val REGISTRATION_STATE_CHANNEL = "com.meta.wearable.flutter/registrationState"
        private const val DEVICES_CHANNEL = "com.meta.wearable.flutter/devices"
        private const val STREAM_STATE_CHANNEL = "com.meta.wearable.flutter/streamState"
        private const val VIDEO_FRAME_INFO_CHANNEL = "com.meta.wearable.flutter/videoFrameInfo"
        private const val STREAM_ERRORS_CHANNEL = "com.meta.wearable.flutter/streamErrors"
    }

    private lateinit var methodChannel: MethodChannel
    private lateinit var registrationStateChannel: EventChannel
    private lateinit var devicesChannel: EventChannel
    private lateinit var streamStateChannel: EventChannel
    private lateinit var videoFrameInfoChannel: EventChannel
    private lateinit var streamErrorsChannel: EventChannel

    private val registrationStateHandler = WearablesStreamHandlers.RegistrationStateHandler()
    private val devicesHandler = WearablesStreamHandlers.DevicesHandler()
    private val streamStateHandler = WearablesStreamHandlers.StreamStateHandler()
    private val videoFrameInfoHandler = WearablesStreamHandlers.VideoFrameInfoHandler()
    private val streamErrorsHandler = WearablesStreamHandlers.StreamErrorsHandler()

    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private lateinit var methodCallHandler: WearablesMethodCallHandler

    private var registrationJob: Job? = null
    private var devicesJob: Job? = null
    private var activityBinding: ActivityPluginBinding? = null

    private val permissionContract = Wearables.RequestPermissionContract()

    private val activityResultListener = PluginRegistry.ActivityResultListener { requestCode, resultCode, data ->
        if (requestCode == WearablesMethodCallHandler.PERMISSION_REQUEST_CODE) {
            val datResult = permissionContract.parseResult(resultCode, data)
            methodCallHandler.handlePermissionResult(datResult)
            true
        } else {
            false
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodCallHandler = WearablesMethodCallHandler(
            scope = pluginScope,
            streamStateHandler = streamStateHandler,
            videoFrameInfoHandler = videoFrameInfoHandler,
            streamErrorsHandler = streamErrorsHandler
        )
        methodCallHandler.application = binding.applicationContext as? Application
        methodCallHandler.textureRegistry = binding.textureRegistry
        methodCallHandler.onInitialized = { startFlowCollection() }
        methodCallHandler.permissionContract = permissionContract

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(methodCallHandler)

        registrationStateChannel = EventChannel(binding.binaryMessenger, REGISTRATION_STATE_CHANNEL)
        registrationStateChannel.setStreamHandler(registrationStateHandler)

        devicesChannel = EventChannel(binding.binaryMessenger, DEVICES_CHANNEL)
        devicesChannel.setStreamHandler(devicesHandler)

        streamStateChannel = EventChannel(binding.binaryMessenger, STREAM_STATE_CHANNEL)
        streamStateChannel.setStreamHandler(streamStateHandler)

        videoFrameInfoChannel = EventChannel(binding.binaryMessenger, VIDEO_FRAME_INFO_CHANNEL)
        videoFrameInfoChannel.setStreamHandler(videoFrameInfoHandler)

        streamErrorsChannel = EventChannel(binding.binaryMessenger, STREAM_ERRORS_CHANNEL)
        streamErrorsChannel.setStreamHandler(streamErrorsHandler)
    }

    fun startFlowCollection() {
        if (registrationJob != null) return
        registrationJob = pluginScope.launch(Dispatchers.Main) {
            Wearables.registrationState.collect { state ->
                registrationStateHandler.eventSink?.success(
                    Converters.registrationStateToString(state)
                )
            }
        }

        devicesJob = pluginScope.launch(Dispatchers.Main) {
            Wearables.devices.collect { devices ->
                devicesHandler.eventSink?.success(
                    Converters.deviceListToList(devices)
                )
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodCallHandler.dispose()
        methodChannel.setMethodCallHandler(null)
        registrationStateChannel.setStreamHandler(null)
        devicesChannel.setStreamHandler(null)
        streamStateChannel.setStreamHandler(null)
        videoFrameInfoChannel.setStreamHandler(null)
        streamErrorsChannel.setStreamHandler(null)
        registrationJob?.cancel()
        devicesJob?.cancel()
        pluginScope.cancel()
    }

    // ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        methodCallHandler.activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        methodCallHandler.activity = null
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        methodCallHandler.activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(activityResultListener)
    }

    override fun onDetachedFromActivity() {
        methodCallHandler.activity = null
        activityBinding?.removeActivityResultListener(activityResultListener)
        activityBinding = null
    }
}
