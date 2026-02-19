import Flutter
import CoreVideo
import UIKit
import MWDATCamera

class VideoFrameRenderer: NSObject, FlutterTexture {
    private var latestPixelBuffer: CVPixelBuffer?
    private let textureRegistry: FlutterTextureRegistry
    private(set) var textureId: Int64 = -1

    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        super.init()
        self.textureId = textureRegistry.register(self)
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }

    func renderFrame(_ videoFrame: VideoFrame) {
        guard let uiImage = videoFrame.makeUIImage(),
              let cgImage = uiImage.cgImage else {
            return
        }

        let width = cgImage.width
        let height = cgImage.height

        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])

        latestPixelBuffer = buffer
        textureRegistry.textureFrameAvailable(textureId)
    }

    func dispose() {
        textureRegistry.unregisterTexture(textureId)
        latestPixelBuffer = nil
    }
}
