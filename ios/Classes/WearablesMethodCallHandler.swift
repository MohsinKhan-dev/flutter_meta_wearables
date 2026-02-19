import Flutter
import MWDATCore
import MWDATCamera

class WearablesMethodCallHandler: NSObject {
    private let streamStateHandler: StreamStateStreamHandler
    private let videoFrameInfoHandler: VideoFrameInfoStreamHandler
    private let streamErrorsHandler: StreamErrorsStreamHandler
    private var textureRegistry: FlutterTextureRegistry?

    private var streamSessionManager: StreamSessionManager?
    private let mockDeviceKitHandler = MockDeviceKitHandler()
    private var wearables: WearablesInterface?

    init(
        streamStateHandler: StreamStateStreamHandler,
        videoFrameInfoHandler: VideoFrameInfoStreamHandler,
        streamErrorsHandler: StreamErrorsStreamHandler
    ) {
        self.streamStateHandler = streamStateHandler
        self.videoFrameInfoHandler = videoFrameInfoHandler
        self.streamErrorsHandler = streamErrorsHandler
        super.init()
    }

    func setTextureRegistry(_ registry: FlutterTextureRegistry) {
        self.textureRegistry = registry
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "initialize":
            handleInitialize(result: result)
        case "startRegistration":
            handleStartRegistration(result: result)
        case "startUnregistration":
            handleStartUnregistration(result: result)
        case "checkPermissionStatus":
            handleCheckPermissionStatus(args: args, result: result)
        case "requestPermission":
            handleRequestPermission(args: args, result: result)
        case "handleUrl":
            handleUrl(args: args, result: result)
        case "startStreamSession":
            handleStartStreamSession(args: args, result: result)
        case "stopStreamSession":
            handleStopStreamSession(result: result)
        case "capturePhoto":
            handleCapturePhoto(result: result)
        case "dispose":
            handleDispose(result: result)
        case "mock_pairRaybanMeta":
            mockDeviceKitHandler.pairRaybanMeta(result: result)
        case "mock_unpairDevice":
            let deviceId = args?["deviceId"] as? String ?? ""
            mockDeviceKitHandler.unpairDevice(deviceId: deviceId, result: result)
        case "mock_deviceAction":
            let deviceId = args?["deviceId"] as? String ?? ""
            let action = args?["action"] as? String ?? ""
            mockDeviceKitHandler.deviceAction(deviceId: deviceId, action: action, result: result)
        case "mock_setCameraFeed":
            let deviceId = args?["deviceId"] as? String ?? ""
            let filePath = args?["filePath"] as? String ?? ""
            mockDeviceKitHandler.setCameraFeed(deviceId: deviceId, filePath: filePath, result: result)
        case "mock_setCapturedImage":
            let deviceId = args?["deviceId"] as? String ?? ""
            let filePath = args?["filePath"] as? String ?? ""
            mockDeviceKitHandler.setCapturedImage(deviceId: deviceId, filePath: filePath, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleInitialize(result: @escaping FlutterResult) {
        do {
            try Wearables.configure()
            wearables = Wearables.shared
            result(nil)
        } catch {
            result(FlutterError(code: "INIT_ERROR", message: "Failed to initialize: \(error)", details: nil))
        }
    }

    private func handleStartRegistration(result: @escaping FlutterResult) {
        guard let wearables = wearables else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        Task { @MainActor in
            do {
                try await wearables.startRegistration()
                result(nil)
            } catch {
                result(FlutterError(code: "REGISTRATION_ERROR", message: "Failed to start registration: \(error)", details: nil))
            }
        }
    }

    private func handleStartUnregistration(result: @escaping FlutterResult) {
        guard let wearables = wearables else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        Task { @MainActor in
            do {
                try await wearables.startUnregistration()
                result(nil)
            } catch {
                result(FlutterError(code: "UNREGISTRATION_ERROR", message: "Failed to unregister: \(error)", details: nil))
            }
        }
    }

    private func handleCheckPermissionStatus(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let wearables = wearables else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        Task { @MainActor in
            do {
                let status = try await wearables.checkPermissionStatus(.camera)
                result(Converters.permissionStatusToString(status))
            } catch {
                result(FlutterError(code: "PERMISSION_ERROR", message: "Permission check failed: \(error)", details: nil))
            }
        }
    }

    private func handleRequestPermission(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let wearables = wearables else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        Task { @MainActor in
            do {
                let status = try await wearables.requestPermission(.camera)
                result(Converters.permissionStatusToString(status))
            } catch {
                result(FlutterError(code: "PERMISSION_ERROR", message: "Permission request failed: \(error)", details: nil))
            }
        }
    }

    private func handleUrl(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let urlString = args?["url"] as? String,
              let url = URL(string: urlString),
              let wearables = wearables else {
            result(false)
            return
        }
        let handled = wearables.handleUrl(url)
        result(handled)
    }

    private func handleStartStreamSession(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let wearables = wearables else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "SDK not initialized", details: nil))
            return
        }
        guard let registry = textureRegistry else {
            result(FlutterError(code: "NO_REGISTRY", message: "Texture registry not available", details: nil))
            return
        }

        let resolutionStr = args?["videoQuality"] as? String ?? "medium"
        let frameRate = args?["frameRate"] as? Int ?? 24
        let resolution = Converters.streamingResolutionFromString(resolutionStr)

        let manager = StreamSessionManager(
            textureRegistry: registry,
            streamStateHandler: streamStateHandler,
            videoFrameInfoHandler: videoFrameInfoHandler,
            streamErrorsHandler: streamErrorsHandler
        )
        streamSessionManager = manager

        let sessionInfo = manager.startSession(resolution: resolution, frameRate: frameRate, wearables: wearables)
        result(sessionInfo)
    }

    private func handleStopStreamSession(result: @escaping FlutterResult) {
        streamSessionManager?.stopSession()
        streamSessionManager = nil
        result(nil)
    }

    private func handleCapturePhoto(result: @escaping FlutterResult) {
        guard let manager = streamSessionManager else {
            result(FlutterError(code: "NO_SESSION", message: "No active stream session", details: nil))
            return
        }
        manager.capturePhoto { photoResult in
            switch photoResult {
            case .success(let data):
                result(data)
            case .failure(let error):
                result(FlutterError(code: "CAPTURE_ERROR", message: "Photo capture failed: \(error.localizedDescription)", details: nil))
            }
        }
    }

    private func handleDispose(result: @escaping FlutterResult) {
        streamSessionManager?.stopSession()
        streamSessionManager = nil
        mockDeviceKitHandler.dispose()
        result(nil)
    }

    func dispose() {
        streamSessionManager?.stopSession()
        streamSessionManager = nil
        mockDeviceKitHandler.dispose()
    }
}
