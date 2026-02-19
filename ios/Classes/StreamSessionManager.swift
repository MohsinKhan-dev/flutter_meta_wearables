import Flutter
import MWDATCamera
import MWDATCore

class StreamSessionManager {
    private var streamSession: StreamSession?
    private var renderer: VideoFrameRenderer?
    private var stateListenerToken: AnyListenerToken?
    private var videoFrameListenerToken: AnyListenerToken?
    private var errorListenerToken: AnyListenerToken?
    private var photoDataListenerToken: AnyListenerToken?
    private var sessionId: String = ""

    private let streamStateHandler: StreamStateStreamHandler
    private let videoFrameInfoHandler: VideoFrameInfoStreamHandler
    private let streamErrorsHandler: StreamErrorsStreamHandler
    private let textureRegistry: FlutterTextureRegistry

    private var pendingPhotoCompletion: ((Result<[String: Any], Error>) -> Void)?

    init(
        textureRegistry: FlutterTextureRegistry,
        streamStateHandler: StreamStateStreamHandler,
        videoFrameInfoHandler: VideoFrameInfoStreamHandler,
        streamErrorsHandler: StreamErrorsStreamHandler
    ) {
        self.textureRegistry = textureRegistry
        self.streamStateHandler = streamStateHandler
        self.videoFrameInfoHandler = videoFrameInfoHandler
        self.streamErrorsHandler = streamErrorsHandler
    }

    func startSession(resolution: StreamingResolution, frameRate: Int, wearables: WearablesInterface) -> [String: Any] {
        stopSession()

        let videoRenderer = VideoFrameRenderer(textureRegistry: textureRegistry)
        renderer = videoRenderer

        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: resolution,
            frameRate: frameRate
        )
        let deviceSelector = AutoDeviceSelector(wearables: wearables)
        let session = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)
        streamSession = session
        sessionId = "\(Int(Date().timeIntervalSince1970 * 1000))"

        stateListenerToken = session.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in
                self?.streamStateHandler.eventSink?(
                    Converters.streamSessionStateToString(state)
                )
            }
        }

        videoFrameListenerToken = session.videoFramePublisher.listen { [weak self] videoFrame in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.renderer?.renderFrame(videoFrame)
                if let image = videoFrame.makeUIImage() {
                    self.videoFrameInfoHandler.eventSink?([
                        "width": Int(image.size.width * image.scale),
                        "height": Int(image.size.height * image.scale),
                        "timestampMs": Int(Date().timeIntervalSince1970 * 1000)
                    ])
                }
            }
        }

        errorListenerToken = session.errorPublisher.listen { [weak self] error in
            Task { @MainActor [weak self] in
                self?.streamErrorsHandler.eventSink?([
                    "code": Converters.streamErrorToString(error),
                    "message": "\(error)"
                ])
            }
        }

        photoDataListenerToken = session.photoDataPublisher.listen { [weak self] photoData in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let data = photoData.data
                if let uiImage = UIImage(data: data) {
                    let result: [String: Any] = [
                        "bytes": FlutterStandardTypedData(bytes: data),
                        "width": Int(uiImage.size.width * uiImage.scale),
                        "height": Int(uiImage.size.height * uiImage.scale)
                    ]
                    self.pendingPhotoCompletion?(.success(result))
                    self.pendingPhotoCompletion = nil
                }
            }
        }

        Task {
            await session.start()
        }

        return [
            "sessionId": sessionId,
            "textureId": videoRenderer.textureId
        ]
    }

    func stopSession() {
        stateListenerToken = nil
        videoFrameListenerToken = nil
        errorListenerToken = nil
        photoDataListenerToken = nil

        if let session = streamSession {
            Task {
                await session.stop()
            }
        }
        streamSession = nil
        renderer?.dispose()
        renderer = nil
        pendingPhotoCompletion = nil
    }

    func capturePhoto(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let session = streamSession else {
            completion(.failure(NSError(domain: "MetaWearables", code: -1, userInfo: [NSLocalizedDescriptionKey: "No active session"])))
            return
        }
        pendingPhotoCompletion = completion
        session.capturePhoto(format: .jpeg)
    }

    func getSessionId() -> String { sessionId }
}
