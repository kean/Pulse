// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

#if !os(macOS)
import UIKit.UIImage
/// Alias for `UIImage`.
typealias PlatformImage = UIImage
#else
import AppKit.NSImage
/// Alias for `NSImage`.
typealias PlatformImage = NSImage
#endif

#if os(watchOS)
import ImageIO
#endif

enum Graphics {
    static func resize(_ image: UIImage, to size: CGSize) -> PlatformImage? {
#if os(macOS)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        let sourceRect = NSMakeRect(0, 0, size.width, size.height)
        let destRect = NSMakeRect(0, 0, newSize.width, newSize.height)
        draw(in: destRect, from: sourceRect, operation: .sourceOver, fraction: CGFloat(1))
        newImage.unlockFocus()
        return newImage
#else
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return thumbnail
#endif
    }

    /// Creates an image thumbnail. Uses significantly less memory than other options.
    static func makeThumbnail(from data: Data, targetSize: CGFloat) -> PlatformImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetSize] as [CFString: Any]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return PlatformImage(cgImage: image)
    }

    static func encode(_ image: PlatformImage, compressionQuality: CGFloat = 0.8) -> Data? {
        guard let source = image.cgImage else {
            return nil
        }
        let data = NSMutableData()
#if os(watchOS)
        let type: String = "public.jpeg"
#else
        let type: String = "public.heic"
#endif
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type as CFString, 1, nil) else {
            return nil
        }
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, source, options)
        CGImageDestinationFinalize(destination)
        guard !data.isEmpty else { return nil }
        return data as Data
    }

    static func makeMetadata(from data: Data) -> [String: String]? {
        guard let image = PlatformImage(data: data) else {
            return nil
        }
        return [
            "ResponsePixelWidth": String(Int(image.size.width)),
            "ResponsePixelHeight": String(Int(image.size.height))
        ]
    }
}

#if os(macOS)
extension NSImage {
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }
}
#endif
