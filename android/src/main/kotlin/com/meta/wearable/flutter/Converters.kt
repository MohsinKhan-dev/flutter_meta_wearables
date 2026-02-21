package com.meta.wearable.flutter

import com.meta.wearable.dat.camera.types.StreamSessionState
import com.meta.wearable.dat.camera.types.VideoQuality
import com.meta.wearable.dat.core.types.DeviceIdentifier
import com.meta.wearable.dat.core.types.PermissionStatus
import com.meta.wearable.dat.core.types.RegistrationState

object Converters {

    fun registrationStateToString(state: RegistrationState): String {
        return when (state) {
            is RegistrationState.Registering -> "registering"
            is RegistrationState.Registered -> "registered"
            is RegistrationState.Unregistering -> "unregistering"
            else -> "unavailable"
        }
    }

    fun permissionStatusToString(status: PermissionStatus): String {
        return when (status) {
            PermissionStatus.Granted -> "granted"
            PermissionStatus.Denied -> "denied"
        }
    }

    fun streamSessionStateToString(state: StreamSessionState): String {
        return when (state) {
            StreamSessionState.STOPPED -> "stopped"
            StreamSessionState.STARTING -> "starting"
            StreamSessionState.STARTED -> "started"
            StreamSessionState.STREAMING -> "streaming"
            StreamSessionState.STOPPING -> "stopping"
            StreamSessionState.CLOSED -> "closed"
        }
    }

    fun videoQualityFromString(value: String): VideoQuality {
        return when (value) {
            "low" -> VideoQuality.LOW
            "medium" -> VideoQuality.MEDIUM
            "high" -> VideoQuality.HIGH
            else -> VideoQuality.MEDIUM
        }
    }

    fun deviceIdentifierToMap(device: DeviceIdentifier): Map<String, String?> {
        return mapOf(
            "id" to device.toString(),
            "name" to null
        )
    }

    fun deviceListToList(devices: Set<DeviceIdentifier>): List<Map<String, String?>> {
        return devices.map { deviceIdentifierToMap(it) }
    }
}
