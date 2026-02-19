import Flutter

#if DEBUG
import MWDATMockDevice
#endif

class MockDeviceKitHandler {
    #if DEBUG
    private var pairedDevices: [String: MockDevice] = [:]
    #endif

    func pairRaybanMeta(result: @escaping FlutterResult) {
        #if DEBUG
        let device = MockDeviceKit.shared.pairRaybanMeta()
        let deviceId = device.deviceIdentifier
        pairedDevices[deviceId] = device
        result(["deviceId": deviceId])
        #else
        result(FlutterError(code: "MOCK_UNAVAILABLE", message: "MockDeviceKit is only available in debug builds", details: nil))
        #endif
    }

    func unpairDevice(deviceId: String, result: @escaping FlutterResult) {
        #if DEBUG
        guard let device = pairedDevices[deviceId] else {
            result(FlutterError(code: "MOCK_ERROR", message: "Device not found: \(deviceId)", details: nil))
            return
        }
        MockDeviceKit.shared.unpairDevice(device)
        pairedDevices.removeValue(forKey: deviceId)
        result(nil)
        #else
        result(FlutterError(code: "MOCK_UNAVAILABLE", message: "MockDeviceKit is only available in debug builds", details: nil))
        #endif
    }

    func deviceAction(deviceId: String, action: String, result: @escaping FlutterResult) {
        #if DEBUG
        guard let device = pairedDevices[deviceId] else {
            result(FlutterError(code: "MOCK_ERROR", message: "Device not found: \(deviceId)", details: nil))
            return
        }
        switch action {
        case "powerOn":
            device.powerOn()
        case "powerOff":
            device.powerOff()
        case "don":
            device.don()
        case "doff":
            device.doff()
        case "fold":
            if let glasses = device as? MockDisplaylessGlasses {
                glasses.fold()
            }
        case "unfold":
            if let glasses = device as? MockDisplaylessGlasses {
                glasses.unfold()
            }
        default:
            result(FlutterError(code: "MOCK_ERROR", message: "Unknown action: \(action)", details: nil))
            return
        }
        result(nil)
        #else
        result(FlutterError(code: "MOCK_UNAVAILABLE", message: "MockDeviceKit is only available in debug builds", details: nil))
        #endif
    }

    func setCameraFeed(deviceId: String, filePath: String, result: @escaping FlutterResult) {
        #if DEBUG
        guard let device = pairedDevices[deviceId] as? MockDisplaylessGlasses else {
            result(FlutterError(code: "MOCK_ERROR", message: "Device not found or not displayless glasses: \(deviceId)", details: nil))
            return
        }
        guard let cameraKit = device.getCameraKit() else {
            result(FlutterError(code: "MOCK_ERROR", message: "Camera kit not available", details: nil))
            return
        }
        let url = URL(fileURLWithPath: filePath)
        Task {
            await cameraKit.setCameraFeed(fileURL: url)
            await MainActor.run {
                result(nil)
            }
        }
        #else
        result(FlutterError(code: "MOCK_UNAVAILABLE", message: "MockDeviceKit is only available in debug builds", details: nil))
        #endif
    }

    func setCapturedImage(deviceId: String, filePath: String, result: @escaping FlutterResult) {
        #if DEBUG
        guard let device = pairedDevices[deviceId] as? MockDisplaylessGlasses else {
            result(FlutterError(code: "MOCK_ERROR", message: "Device not found or not displayless glasses: \(deviceId)", details: nil))
            return
        }
        guard let cameraKit = device.getCameraKit() else {
            result(FlutterError(code: "MOCK_ERROR", message: "Camera kit not available", details: nil))
            return
        }
        let url = URL(fileURLWithPath: filePath)
        Task {
            await cameraKit.setCapturedImage(fileURL: url)
            await MainActor.run {
                result(nil)
            }
        }
        #else
        result(FlutterError(code: "MOCK_UNAVAILABLE", message: "MockDeviceKit is only available in debug builds", details: nil))
        #endif
    }

    func dispose() {
        #if DEBUG
        pairedDevices.removeAll()
        #endif
    }
}
