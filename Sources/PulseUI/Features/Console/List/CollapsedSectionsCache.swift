// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

/// Persists section names the user has explicitly collapsed per
/// `(mode, groupBy)` in a single JSON file shared across stores.
final class CollapsedSectionsCache {
    static let shared = CollapsedSectionsCache()

    private let fileURL: URL
    private var cache: [String: Set<String>]

    init(fileURL: URL = URL.temp.appending(filename: "pulse-collapsed-sections.json")) {
        self.fileURL = fileURL
        self.cache = Self.load(from: fileURL)
    }

    func sections(forKey key: String) -> Set<String> {
        cache[key] ?? []
    }

    func setSections(_ sections: Set<String>, forKey key: String) {
        if sections.isEmpty {
            guard cache.removeValue(forKey: key) != nil else { return }
        } else {
            guard cache[key] != sections else { return }
            cache[key] = sections
        }
        save()
    }

    private static func load(from url: URL) -> [String: Set<String>] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: Set<String>].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
