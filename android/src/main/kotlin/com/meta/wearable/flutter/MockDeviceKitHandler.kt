package com.meta.wearable.flutter

import android.app.Application
import android.net.Uri
import com.meta.wearable.dat.mockdevice.MockDeviceKit
import com.meta.wearable.dat.mockdevice.api.MockDeviceKitInterface
import com.meta.wearable.dat.mockdevice.api.MockRaybanMeta
import io.flutter.plugin.common.MethodChannel

class MockDeviceKitHandler(private val application: Application) {
    private val mockDeviceKit: MockDeviceKitInterface by lazy {
        MockDeviceKit.getInstance(application.applicationContext)
    }
    private val pairedDevices = mutableMapOf<String, MockRaybanMeta>()

    fun pairRaybanMeta(result: MethodChannel.Result) {
        try {
            val mockDevice = mockDeviceKit.pairRaybanMeta()
            val deviceId = System.currentTimeMillis().toString()
            pairedDevices[deviceId] = mockDevice
            result.success(mapOf("deviceId" to deviceId))
        } catch (e: Exception) {
            result.error("MOCK_ERROR", "Failed to pair mock device: ${e.message}", null)
        }
    }

    fun unpairDevice(deviceId: String, result: MethodChannel.Result) {
        try {
            val device = pairedDevices[deviceId]
            if (device != null) {
                mockDeviceKit.unpairDevice(device)
                pairedDevices.remove(deviceId)
                result.success(null)
            } else {
                result.error("MOCK_ERROR", "Device not found: $deviceId", null)
            }
        } catch (e: Exception) {
            result.error("MOCK_ERROR", "Failed to unpair device: ${e.message}", null)
        }
    }

    fun deviceAction(deviceId: String, action: String, result: MethodChannel.Result) {
        try {
            val device = pairedDevices[deviceId]
            if (device == null) {
                result.error("MOCK_ERROR", "Device not found: $deviceId", null)
                return
            }
            when (action) {
                "powerOn" -> device.powerOn()
                "powerOff" -> device.powerOff()
                "don" -> device.don()
                "doff" -> device.doff()
                "fold" -> device.fold()
                "unfold" -> device.unfold()
                else -> {
                    result.error("MOCK_ERROR", "Unknown action: $action", null)
                    return
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("MOCK_ERROR", "Failed to execute action: ${e.message}", null)
        }
    }

    fun setCameraFeed(deviceId: String, filePath: String, result: MethodChannel.Result) {
        try {
            val device = pairedDevices[deviceId]
            if (device == null) {
                result.error("MOCK_ERROR", "Device not found: $deviceId", null)
                return
            }
            device.getCameraKit().setCameraFeed(Uri.parse(filePath))
            result.success(null)
        } catch (e: Exception) {
            result.error("MOCK_ERROR", "Failed to set camera feed: ${e.message}", null)
        }
    }

    fun setCapturedImage(deviceId: String, filePath: String, result: MethodChannel.Result) {
        try {
            val device = pairedDevices[deviceId]
            if (device == null) {
                result.error("MOCK_ERROR", "Device not found: $deviceId", null)
                return
            }
            device.getCameraKit().setCapturedImage(Uri.parse(filePath))
            result.success(null)
        } catch (e: Exception) {
            result.error("MOCK_ERROR", "Failed to set captured image: ${e.message}", null)
        }
    }

    fun dispose() {
        pairedDevices.clear()
    }
}
