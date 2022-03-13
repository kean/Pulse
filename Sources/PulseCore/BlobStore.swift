// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import CommonCrypto

/// Blob storage.
///
/// - Stores blobs using file system
/// - Automatically deduplicates files
/// - Has size limits and performs LRU cleanup
///
/// Thread-safe. Can be used with multiple logger stores.
final class BlobStore {
    /// When performing a sweep, the cache will remote entries until the size of
    /// the remaining items is lower than or equal to `sizeLimit * trimRatio` and
    /// the total count is lower than or equal to `countLimit * trimRatio`. `0.7`
    /// by default.
    private let trimRatio = 0.7

    /// The path for the directory managed by the cache.
    let path: URL

    /// The number of seconds between each LRU sweep. 30 by default.
    /// The first sweep is performed right after the cache is initialized.
    ///
    /// Sweeps are performed in a background and can be performed in parallel
    /// with reading.
    private let sweepInterval: TimeInterval = 30

    /// The delay after which the initial sweep is performed. 5 by default.
    /// The initial sweep is performed after a delay to avoid competing with
    /// other subsystems for the resources.
    private let initialSweepDelay: TimeInterval = 5

    /// A queue which is used for disk I/O.
    private let queue = DispatchQueue(label: "com.github.kean.pulse.blob-storage", qos: .utility)

    /// Creates a cache instance with a given path.
    init(path: URL) {
        self.path = path

        try? Files.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
        queue.asyncAfter(deadline: .now() + initialSweepDelay) { [weak self] in
            self?.performAndScheduleSweep()
        }
    }

    // MARK: Store

    func getData(for key: String) -> Data? {
        try? Data(contentsOf: url(for: key))
    }

    /// Stored data in the blob storage. If the file with the same contents is
    /// already stored, returns the existing file.
    func storeData(_ data: Data?) -> String? {
        guard let data = data, !data.isEmpty else {
            return nil
        }
        let hash = data.sha256
        let url = path.appendingPathComponent(hash, isDirectory: false)
        guard !Files.fileExists(atPath: url.absoluteString) else {
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
    func removeData(for key: String) {
        try? Files.removeItem(at: url(for: key))
    }

    /// Removes all items. The method returns instantly, the data is removed
    /// asynchronously.
    func removeAll() {
        try? Files.removeItem(at: path)
        try? Files.createDirectory(at: path, withIntermediateDirectories: true, attributes: nil)
    }

    func copyContents(to url: URL) throws {
        try Files.copyItem(at: path, to: url)
    }

    // MARK: Managing URLs

    /// Returns `url` for the given cache key.
    func url(for key: String) -> URL {
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
    func sweep() {
        queue.sync(execute: performSweep)
    }

    /// Discards the least recently used items first.
    private func performSweep() {
        var items = contents(keys: [.contentAccessDateKey, .totalFileAllocatedSizeKey])
        guard !items.isEmpty else {
            return
        }
        var size = items.reduce(0) { $0 + ($1.meta.totalFileAllocatedSize ?? 0) }
        var count = items.count

        guard size > LoggerStore.blobsSizeLimit else {
            return // All good, no need to perform any work.
        }

        let sizeLimit = Int(Double(LoggerStore.blobsSizeLimit) * trimRatio)

        // Most recently accessed items first
        let past = Date.distantPast
        items.sort { // Sort in place
            ($0.meta.contentAccessDate ?? past) > ($1.meta.contentAccessDate ?? past)
        }

        // Remove the items until it satisfies both size and count limits.
        while size > sizeLimit, let item = items.popLast() {
            size -= (item.meta.totalFileAllocatedSize ?? 0)
            count -= 1
            try? Files.removeItem(at: item.url)
        }
    }

    // MARK: Contents

    private struct Entry {
        let url: URL
        let meta: URLResourceValues
    }

    private func contents(keys: [URLResourceKey] = []) -> [Entry] {
        guard let urls = try? Files.contentsOfDirectory(at: path, includingPropertiesForKeys: keys, options: .skipsHiddenFiles) else {
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
    var totalCount: Int {
        contents().count
    }

    /// The total file size of items written on disk.
    ///
    /// Uses `URLResourceKey.fileSizeKey` to calculate the size of each entry.
    /// The total allocated size (see `totalAllocatedSize`. on disk might
    /// actually be bigger.
    ///
    /// - warning: Requires disk IO, avoid using from the main thread.
    var totalSize: Int {
        contents(keys: [.fileSizeKey]).reduce(0) {
            $0 + ($1.meta.fileSize ?? 0)
        }
    }

    /// The total file allocated size of all the items written on disk.
    ///
    /// Uses `URLResourceKey.totalFileAllocatedSizeKey`.
    ///
    /// - warning: Requires disk IO, avoid using from the main thread.
    var totalAllocatedSize: Int {
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
