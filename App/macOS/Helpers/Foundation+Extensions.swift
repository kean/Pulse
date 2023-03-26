// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

extension URL {
    static var library: URL {
        let url = Files.urls(for: .libraryDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/dev/null")
        Files.createDirectoryIfNeeded(at: url)
        return url
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
}
