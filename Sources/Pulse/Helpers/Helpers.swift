// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import CommonCrypto

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
#if os(tvOS)
        let searchPath = FileManager.SearchPathDirectory.cachesDirectory
#else
        let searchPath = FileManager.SearchPathDirectory.libraryDirectory
#endif
        var url = Files.urls(for: searchPath, in: .userDomainMask).first?
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

extension URL {
    func directoryTotalSize() throws -> Int64 {
        guard let urls = Files.enumerator(at: self, includingPropertiesForKeys: nil)?.allObjects as? [URL] else { return 0 }
        return try urls.lazy.reduce(Int64(0)) {
            let size = try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize
            return Int64(size ?? 0) + $0
        }
    }

    func getHost() -> String? {
        if let host = self.host {
            return host
        }
        if self.scheme == nil, let url = URL(string: "https://" + self.absoluteString) {
            return url.host ?? "" // URL(string: "example.com")?.host with not scheme returns host: ""
        }
        return nil
    }
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
