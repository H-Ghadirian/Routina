import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum TaskImageProcessor {
    private static let maxPixelDimension = 1_600
    private static let preferredByteCount = 450_000
    private static let compressionQualities: [CGFloat] = [0.72, 0.62, 0.52, 0.44]

    static func compressedImageData(from originalData: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(originalData as CFData, nil) else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension
        ] as CFDictionary

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }

        var smallestData: Data?
        for quality in compressionQualities {
            guard let data = jpegData(from: cgImage, compressionQuality: quality) else { continue }
            smallestData = data
            if data.count <= preferredByteCount {
                return data
            }
        }

        return smallestData
    }

    static func compressedImageData(fromFileAt url: URL) -> Data? {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return compressedImageData(from: data)
    }

    private static func jpegData(from cgImage: CGImage, compressionQuality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
}
