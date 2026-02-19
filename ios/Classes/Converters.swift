import Foundation
import MWDATCore
import MWDATCamera

struct Converters {

    static func registrationStateToString(_ state: RegistrationState) -> String {
        switch state {
        case .registering:
            return "registering"
        case .registered:
            return "registered"
        default:
            return "unavailable"
        }
    }

    static func permissionStatusToString(_ status: PermissionStatus) -> String {
        switch status {
        case .granted:
            return "granted"
        case .denied:
            return "denied"
        @unknown default:
            return "denied"
        }
    }

    static func streamSessionStateToString(_ state: StreamSessionState) -> String {
        switch state {
        case .stopped:
            return "stopped"
        case .starting:
            return "starting"
        case .waitingForDevice:
            return "waitingForDevice"
        case .streaming:
            return "streaming"
        case .paused:
            return "paused"
        case .stopping:
            return "stopping"
        @unknown default:
            return "stopped"
        }
    }

    static func streamErrorToString(_ error: StreamSessionError) -> String {
        switch error {
        case .internalError:
            return "internalError"
        case .deviceNotFound:
            return "deviceNotFound"
        case .deviceNotConnected:
            return "deviceNotConnected"
        case .timeout:
            return "timeout"
        case .videoStreamingError:
            return "videoStreamingError"
        case .audioStreamingError:
            return "audioStreamingError"
        case .permissionDenied:
            return "permissionDenied"
        case .hingesClosed:
            return "hingesClosed"
        @unknown default:
            return "unknown"
        }
    }

    static func streamingResolutionFromString(_ value: String) -> StreamingResolution {
        switch value {
        case "low":
            return .low
        default:
            return .low
        }
    }

    static func deviceIdentifierToMap(_ device: DeviceIdentifier) -> [String: String?] {
        return [
            "id": "\(device)",
            "name": nil
        ]
    }

    static func deviceListToArray(_ devices: [DeviceIdentifier]) -> [[String: String?]] {
        return devices.map { deviceIdentifierToMap($0) }
    }
}
