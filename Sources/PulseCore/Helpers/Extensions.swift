// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import CommonCrypto

func descriptionForStatusCode(_ statusCode: Int) -> String {
    switch statusCode {
    case 200: return "200 (OK)"
    default: return "\(statusCode) (\( HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized))"
    }
}

var Files: FileManager { FileManager.default }

extension FileManager {
    @discardableResult
    func createDirectoryIfNeeded(at url: URL) -> Bool {
        guard !fileExists(atPath: url.path) else { return false }
        try? createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
        return true
    }
}

extension URL {
    static var temp: URL {
        let url = Files.temporaryDirectory
            .appendingPathComponent("com.github.kean.logger", isDirectory: true)
        Files.createDirectoryIfNeeded(at: url)
        return url
    }

    static var logs: URL {
        var url = Files.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("com.github.kean.logger", isDirectory: true)  ?? URL(fileURLWithPath: "/dev/null")
        if !Files.createDirectoryIfNeeded(at: url) {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
        return url
    }
}

extension Data {
    /// Calculates SHA256 from the given string and returns its hex representation.
    ///
    /// ```swift
    /// print("http://test.com".data(using: .utf8)!.sha256)
    /// // prints "8b408a0c7163fdfff06ced3e80d7d2b3acd9db900905c4783c28295b8c996165"
    /// ```
    var sha256: String {
        let hash = withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(count), &hash)
            return hash
        }
        return hash.map({ String(format: "%02x", $0) }).joined()
    }
}

extension URLRequest {
    func httpBodyStreamData() -> Data? {
        guard let bodyStream = self.httpBodyStream else {
            return nil
        }

        // Will read 16 chars per iteration. Can use bigger buffer if needed
        let bufferSize: Int = 16
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

        bodyStream.open()
        defer {
            buffer.deallocate()
            bodyStream.close()
        }

        var bodyStreamData = Data()

        while bodyStream.hasBytesAvailable {
            let readData = bodyStream.read(buffer, maxLength: bufferSize)
            bodyStreamData.append(buffer, count: readData)
        }

        return bodyStreamData
    }
}

extension Archive {
    func getData(for entry: Entry) -> Data? {
        var data = Data()
        _ = try? extract(entry, skipCRC32: true) {
            data.append($0)
        }
        return data
    }
}

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
    /// Creates an image thumbnail. Uses significantly less memory than other options.
    static func makeThumbnail(from data: Data, targetSize: CGFloat) -> PlatformImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: targetSize] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else {
            return nil
        }
        return PlatformImage(cgImage: image)
    }

    static func encode(_ image: PlatformImage) -> Data? {
        guard let source = image.cgImage else {
            return nil
        }
        let data = NSMutableData()
        let type: String = "public.heic"
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type as CFString, 1, nil) else {
            return nil
        }
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: 0.33
        ]
        CGImageDestinationAddImage(destination, source, options)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}

extension CGImage {
    /// Returns `true` if the image doesn't contain alpha channel.
    var isOpaque: Bool {
        let alpha = alphaInfo
        return alpha == .none || alpha == .noneSkipFirst || alpha == .noneSkipLast
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

extension URL {
    func directoryTotalAllocatedSize() throws -> Int64 {
        guard let urls = Files.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return 0 }
        return try urls.lazy.reduce(Int64(0)) {
            let size = try $1.resourceValues(forKeys: [.totalFileAllocatedSizeKey]).totalFileAllocatedSize
            return Int64(size ?? 0) + $0
        }
    }
}
