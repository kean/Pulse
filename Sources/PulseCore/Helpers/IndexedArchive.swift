// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

// `ZipFoundation.Archive` re-reads the archive's directory every time you access
// an entry. `IndexedArchive` creates an in-memory index to avoid this overhead.
// And it adds some convenience APIs on top of `ZipFoundation.Archive`.
final class IndexedArchive: @unchecked Sendable {
    private let archive: Archive
    private let index: [String: Entry]

    convenience init?(url: URL) {
        guard let archive = Archive(url: url, accessMode: .read) else {
            return nil
        }
        self.init(archive: archive)
    }

    private init(archive: Archive) {
        self.archive = archive
        var index = [String: Entry]()
        for entry in archive {
            index[entry.path] = entry
        }
        self.index = index
    }

    func extract(_ entry: Entry, to url: URL) throws {
        _ = try archive.extract(entry, to: url, skipCRC32: true)
    }

    func getData(for name: String) -> Data? {
        guard let entry = index[name] else {
            return nil
        }
        return archive.getData(for: entry)
    }

    subscript(path: String) -> Entry? {
        index[path]
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
