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
    func appending(filename: String) -> URL {
        appendingPathComponent(filename, isDirectory: false)
    }

    func appending(directory: String) -> URL {
        appendingPathComponent(directory, isDirectory: true)
    }

    static var temp: URL {
        let url = Files.temporaryDirectory
            .appending(directory: "com.github.kean.logger")
        Files.createDirectoryIfNeeded(at: url)
        return url
    }

    static var logs: URL {
        var url = Files.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appending(directory: "Logs")
            .appending(directory: "com.github.kean.logger")  ?? URL(fileURLWithPath: "/dev/null")
        if !Files.createDirectoryIfNeeded(at: url) {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
        return url
    }
}

extension Data {
    /// Calculates SHA1 from the given string and returns its hex representation.
    ///
    /// ```swift
    /// print("http://test.com".data(using: .utf8)!.sha1)
    /// // prints "c6b6cafcb77f54d43cd1bd5361522a5e0c074b65"
    /// ```
    var sha1: Data {
        Data(withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            CC_SHA1(bytes.baseAddress, CC_LONG(count), &hash)
            return hash
        })
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

extension URLRequest {
    func httpBodyStreamData() -> Data? {
        guard let bodyStream = self.httpBodyStream else {
            return nil
        }
        let bufferSize: Int = 1024
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
#if os(watchOS)
        let type: String = "public.jpeg"
#else
        let type: String = "public.heic"
#endif
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type as CFString, 1, nil) else {
            return nil
        }
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: 0.33
        ]
        CGImageDestinationAddImage(destination, source, options)
        CGImageDestinationFinalize(destination)
        guard !data.isEmpty else { return nil }
        return data as Data
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
    func directoryTotalSize() throws -> Int64 {
        guard let urls = Files.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return 0 }
        return try urls.lazy.reduce(Int64(0)) {
            let size = try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return Int64(size ?? 0) + $0
        }
    }
}

@discardableResult
func benchmark<T>(title: String, operation: () throws -> T) rethrows -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let value = try operation()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Time elapsed for \(title): \(timeElapsed * 1000.0) ms.")
    return value
}

final class WeakLoggerStore {
    weak var store: LoggerStore?

    init(store: LoggerStore?) {
        self.store = store
    }

    /// The key for `NSManagedObjectContext` `userInfo`.
    static let loggerStoreKey = "com.github.kean.pulse.associated-logger-store"
}

struct TemporaryDirectory {
    let url: URL

    init() {
        url = URL.temp.appending(directory: UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

extension Data {
    func compressed() throws -> Data {
        try (self as NSData).compressed(using: .lzfse) as Data
    }

    func decompressed() throws -> Data {
        try (self as NSData).decompressed(using: .lzfse) as Data
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
