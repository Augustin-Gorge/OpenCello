import Foundation
import CoreVideo

struct ProfileFrame {
    let lines: [HoughLine]
    let timestamp: TimeInterval
}

/// Analyse d'une image de profil : downsampling, grayscale, lignes de Hough.
final class ProfileAnalyzer {
    private let width = 320
    private let height = 180

    func analyze(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> ProfileFrame? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
        let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard imageWidth > 0, imageHeight > 0 else { return nil }

        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        var gray = [UInt8](repeating: 0, count: width * height)
        let stepX = Double(imageWidth) / Double(width)
        let stepY = Double(imageHeight) / Double(height)

        for y in 0..<height {
            let sourceY = min(imageHeight - 1, Int(Double(y) * stepY))
            let row = sourceY * bytesPerRow
            for x in 0..<width {
                let sourceX = min(imageWidth - 1, Int(Double(x) * stepX))
                let offset = row + sourceX * 4
                let blue = Double(bytes[offset])
                let green = Double(bytes[offset + 1])
                let red = Double(bytes[offset + 2])
                let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
                gray[y * width + x] = UInt8(max(0, min(255, luminance)))
            }
        }

        let lines = LineDetector.detect(gray: gray, width: width, height: height)
        return ProfileFrame(lines: lines, timestamp: timestamp)
    }
}
