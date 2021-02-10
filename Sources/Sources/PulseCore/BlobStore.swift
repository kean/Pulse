// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CommonCrypto

/// Blob storage.
///
/// - Stores blobs using file system
/// - Automatically deduplicates files
/// - Has size limits and performs LRU cleanup
///
/// Thread-safe. Can be used with multiple logger stores.
public final class BlobStore {
    /// A cache key.
    public typealias Key = String

    /// Size limit in bytes. `300 Mb` by default.
    ///
    /// Changes to `sizeLimit` will take effect when the next LRU sweep is run.
    public var sizeLimit: Int? = 1024 * 1024 * 300

    /// When performing a sweep, the cache will remote entries until the size of
    /// the remaining items is lower than or equal to `sizeLimit * trimRatio` and
    /// the total count is lower than or equal to `countLimit * trimRatio`. `0.7`
    /// by default.
    var trimRatio = 0.7

    /// The path for the directory managed by the cache.
    public let path: URL

    /// The number of seconds between each LRU sweep. 30 by default.
    /// The first sweep is performed right after the cache is initialized.
    ///
    /// Sweeps are performed in a background and can be performed in parallel
    /// with reading.
    public var sweepInterval: TimeInterval = 30

    /// The delay after which the initial sweep is performed. 5 by default.
    /// The initial sweep is performed after a delay to avoid competing with
    /// other subsystems for the resources.
    private var initialSweepDelay: TimeInterval = 5

    /// A queue which is used for disk I/O.
    private let queue = DispatchQueue(label: "com.github.kean.pulse.blob-storage", target: .global(qos: .utility))

    // Returns the default blob storage.
    public static let `default` = BlobStore(name: "com.github.kean.logger")

    private let isReadonly: Bool

    /// Creates a `BlobStore` with the given name.
    /// - Parameters:
    ///   - name: The name of the `NSPersistentContainer` to be used for persistency.
    /// By default, the logger stores logs in Library/Blobs directory which is
    /// excluded from the backup.
    public convenience init(name: String) {
        var logsUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs", isDirectory: true) ?? URL(fileURLWithPath: "/dev/null")

        let logsPath = logsUrl.absoluteString

        if !FileManager.default.fileExists(atPath: logsPath) {
            try? FileManager.default.createDirectory(at: logsUrl, withIntermediateDirectories: true, attributes: [:])
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? logsUrl.setResourceValues(resourceValues)
        }

        let storeURL = logsUrl.appendingPathComponent("\(name).blobs", isDirectory: true)
        self.init(path: storeURL)
    }

    /// Creates a cache instance with a given path.
    /// The default implementation generates a filename using SHA1 hash function.
    /// - parameter isReadonly: If `true`, the store is readyonly. LRU cleanup disabled.
    public init(path: URL, isReadonly: Bool = false) {
        self.path = path
        self.isReadonly = isReadonly

        if !isReadonly {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
            queue.asyncAfter(deadline: .now() + initialSweepDelay) { [weak self] in
                self?.performAndScheduleSweep()
            }
        } else {
            sizeLimit = nil
        }
    }

    // MARK: Store

    public func getData(for key: Key) -> Data? {
        try? Data(contentsOf: url(for: key))
    }

    /// Stored data in the blob storage. If the file with the same contents is
    /// already stored, returns the existing file.
    public func storeData(_ data: Data?) -> Key? {
        guard !isReadonly else {
            return nil
        }
        guard let data = data, !data.isEmpty else {
            return nil
        }
        let hash = data.sha256
        let url = path.appendingPathComponent(hash, isDirectory: false)
        guard !FileManager.default.fileExists(atPath: url.absoluteString) else {
            return hash // The file with same content is already stored.
        }
        do {
            try data.write(to: url)
            return hash
        } catch {
            return nil
        }
    }

    /// Removes data for the given key. The method returns instantly, the data
    /// is removed asynchronously.
    public func removeData(for key: Key) {
        guard !isReadonly else {
            return
        }
        try? FileManager.default.removeItem(at: url(for: key))
    }

    /// Removes all items. The method returns instantly, the data is removed
    /// asynchronously.
    public func removeAll() {
        guard !isReadonly else {
            return
        }
        try? FileManager.default.removeItem(at: path)
        try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
    }

    public func copyContents(to url: URL) throws {
        try FileManager.default.copyItem(at: path, to: url)
    }

    // MARK: Managing URLs

    /// Returns `url` for the given cache key.
    public func url(for key: Key) -> URL {
        path.appendingPathComponent(key, isDirectory: false)
    }

    // MARK: Sweep

    private func performAndScheduleSweep() {
        performSweep()
        queue.asyncAfter(deadline: .now() + sweepInterval) { [weak self] in
            self?.performAndScheduleSweep()
        }
    }

    /// Synchronously performs a cache sweep and removes the least recently items
    /// which no longer fit in cache.
    public func sweep() {
        guard !isReadonly else {
            return
        }
        queue.sync(execute: performSweep)
    }

    /// Discards the least recently used items first.
    private func performSweep() {
        guard let unwrappedSizeLimit = self.sizeLimit else {
            return
        }

        var items = contents(keys: [.contentAccessDateKey, .totalFileAllocatedSizeKey])
        guard !items.isEmpty else {
            return
        }
        var size = items.reduce(0) { $0 + ($1.meta.totalFileAllocatedSize ?? 0) }
        var count = items.count
        let sizeLimit = Int(Double(unwrappedSizeLimit) * trimRatio)

        guard size > sizeLimit else {
            return // All good, no need to perform any work.
        }

        // Most recently accessed items first
        let past = Date.distantPast
        items.sort { // Sort in place
            ($0.meta.contentAccessDate ?? past) > ($1.meta.contentAccessDate ?? past)
        }

        // Remove the items until it satisfies both size and count limits.
        while size > sizeLimit, let item = items.popLast() {
            size -= (item.meta.totalFileAllocatedSize ?? 0)
            count -= 1
            try? FileManager.default.removeItem(at: item.url)
        }
    }

    // MARK: Contents

    private struct Entry {
        let url: URL
        let meta: URLResourceValues
    }

    private func contents(keys: [URLResourceKey] = []) -> [Entry] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else {
            return []
        }
        let keys = Set(keys)
        return urls.compactMap {
            guard let meta = try? $0.resourceValues(forKeys: keys) else {
                return nil
            }
            return Entry(url: $0, meta: meta)
        }
    }

    // MARK: Inspection

    /// The total number of items in the cache.
    /// - warning: Requires disk IO, avoid using from the main thread.
    public var totalCount: Int {
        contents().count
    }

    /// The total file size of items written on disk.
    ///
    /// Uses `URLResourceKey.fileSizeKey` to calculate the size of each entry.
    /// The total allocated size (see `totalAllocatedSize`. on disk might
    /// actually be bigger.
    ///
    /// - warning: Requires disk IO, avoid using from the main thread.
    public var totalSize: Int {
        contents(keys: [.fileSizeKey]).reduce(0) {
            $0 + ($1.meta.fileSize ?? 0)
        }
    }

    /// The total file allocated size of all the items written on disk.
    ///
    /// Uses `URLResourceKey.totalFileAllocatedSizeKey`.
    ///
    /// - warning: Requires disk IO, avoid using from the main thread.
    public var totalAllocatedSize: Int {
        contents(keys: [.totalFileAllocatedSizeKey]).reduce(0) {
            $0 + ($1.meta.totalFileAllocatedSize ?? 0)
        }
    }
}

private extension Data {
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
