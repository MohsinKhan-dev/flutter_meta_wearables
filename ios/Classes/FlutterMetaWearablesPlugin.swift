import Flutter
import UIKit
import MWDATCore

public class FlutterMetaWearablesPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {
    private let registrationStateHandler = RegistrationStateStreamHandler()
    private let devicesHandler = DevicesStreamHandler()
    private let streamStateHandler = StreamStateStreamHandler()
    private let videoFrameInfoHandler = VideoFrameInfoStreamHandler()
    private let streamErrorsHandler = StreamErrorsStreamHandler()

    private let methodCallHandler: WearablesMethodCallHandler

    private var registrationTask: Task<Void, Never>?
    private var devicesTask: Task<Void, Never>?

    override init() {
        methodCallHandler = WearablesMethodCallHandler(
            streamStateHandler: streamStateHandler,
            videoFrameInfoHandler: videoFrameInfoHandler,
            streamErrorsHandler: streamErrorsHandler
        )
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = FlutterMetaWearablesPlugin()
        instance.methodCallHandler.setTextureRegistry(registrar.textures())

        let methodChannel = FlutterMethodChannel(
            name: "com.meta.wearable.flutter/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let registrationStateChannel = FlutterEventChannel(
            name: "com.meta.wearable.flutter/registrationState",
            binaryMessenger: registrar.messenger()
        )
        registrationStateChannel.setStreamHandler(instance.registrationStateHandler)

        let devicesChannel = FlutterEventChannel(
            name: "com.meta.wearable.flutter/devices",
            binaryMessenger: registrar.messenger()
        )
        devicesChannel.setStreamHandler(instance.devicesHandler)

        let streamStateChannel = FlutterEventChannel(
            name: "com.meta.wearable.flutter/streamState",
            binaryMessenger: registrar.messenger()
        )
        streamStateChannel.setStreamHandler(instance.streamStateHandler)

        let videoFrameInfoChannel = FlutterEventChannel(
            name: "com.meta.wearable.flutter/videoFrameInfo",
            binaryMessenger: registrar.messenger()
        )
        videoFrameInfoChannel.setStreamHandler(instance.videoFrameInfoHandler)

        let streamErrorsChannel = FlutterEventChannel(
            name: "com.meta.wearable.flutter/streamErrors",
            binaryMessenger: registrar.messenger()
        )
        streamErrorsChannel.setStreamHandler(instance.streamErrorsHandler)

        registrar.addApplicationDelegate(instance)

        instance.startAsyncStreams()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        methodCallHandler.handle(call, result: result)
    }

    // Handle deep link callbacks for OAuth
    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        do {
            try Wearables.configure()
            return Wearables.shared.handleUrl(url)
        } catch {
            return false
        }
    }

    private func startAsyncStreams() {
        // Start registration state stream after SDK is configured
        registrationTask = Task { @MainActor in
            do {
                try Wearables.configure()
                let wearables = Wearables.shared
                for await state in wearables.registrationStateStream() {
                    self.registrationStateHandler.eventSink?(
                        Converters.registrationStateToString(state)
                    )
                }
            } catch {
                // SDK not configured yet, streams will start after initialize()
            }
        }

        devicesTask = Task { @MainActor in
            do {
                try Wearables.configure()
                let wearables = Wearables.shared
                for await devices in wearables.devicesStream() {
                    self.devicesHandler.eventSink?(
                        Converters.deviceListToArray(devices)
                    )
                }
            } catch {
                // SDK not configured yet, streams will start after initialize()
            }
        }
    }

    deinit {
        registrationTask?.cancel()
        devicesTask?.cancel()
        methodCallHandler.dispose()
    }
}
