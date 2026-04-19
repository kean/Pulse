// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import SwiftUI
import Combine

/// A persisted entry in the recent filters list.
package struct ConsoleRecentFilter: Identifiable, Hashable, Codable {
    package let id: UUID
    package var filters: ConsoleFilters
    package var lastUsedDate: Date

    package init(id: UUID = UUID(), filters: ConsoleFilters, lastUsedDate: Date = Date()) {
        self.id = id
        self.filters = filters
        self.lastUsedDate = lastUsedDate
    }
}

/// Persists recently-used filter sets per ``ConsoleMode``. Mirrors
/// ``ConsoleSearchRecentSearchesStore`` in shape — JSON-encoded into
/// `UserDefaults`, capped, with most-recent-first ordering.
package final class ConsoleRecentFiltersStore: ObservableObject {
    private let mode: ConsoleMode

    /// Most-recent first.
    @Published package private(set) var recents: [ConsoleRecentFilter] = []

    private static let limit = 10

    package init(mode: ConsoleMode) {
        self.mode = mode
        self.recents = decode([ConsoleRecentFilter].self, from: UserDefaults.standard.string(forKey: storeKey) ?? "[]") ?? []
    }

    /// Creates a store pre-populated with the given entries. Does **not** read
    /// from or write to `UserDefaults` — intended for previews and tests.
    init(mode: ConsoleMode, recents: [ConsoleRecentFilter]) {
        self.mode = mode
        self.recents = recents
    }

    private var storeKey: String { "\(mode.rawValue)-recent-filters" }

    /// Saves the given filters as the most recent entry. No-ops when the
    /// filters are equivalent to the empty default, or when they would be a
    /// duplicate of an existing entry.
    package func save(_ filters: ConsoleFilters) {
        if filters.isDefault { return }

        // Move to front if an equivalent entry already exists, refreshing timestamp.
        if let existingIndex = recents.firstIndex(where: { $0.filters == filters }) {
            var existing = recents.remove(at: existingIndex)
            existing.lastUsedDate = Date()
            recents.insert(existing, at: 0)
        } else {
            recents.insert(ConsoleRecentFilter(filters: filters), at: 0)
        }
        persist()
    }

    package func remove(_ entry: ConsoleRecentFilter) {
        recents.removeAll { $0.id == entry.id }
        persist()
    }

    package func clear() {
        recents = []
        persist()
    }

    private func persist() {
        while recents.count > Self.limit {
            recents.removeLast()
        }
        UserDefaults.standard.set(encode(recents) ?? "[]", forKey: storeKey)
    }
}

private func encode<T: Encodable>(_ value: T) -> String? {
    (try? JSONEncoder().encode(value)).flatMap {
        String(data: $0, encoding: .utf8)
    }
}

private func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
    string.data(using: .utf8).flatMap {
        try? JSONDecoder().decode(type, from: $0)
    }
}

#endif
