// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation
import SwiftUI

final class ConsoleSearchRecentSearchesStore {
    private let mode: ConsoleMode

    private(set) var searches: [ConsoleSearchTerm] = []
    private(set) var filters: [ConsoleSearchFilter] = []

    init(mode: ConsoleMode) {
        self.mode = mode

        self.searches = decode([ConsoleSearchTerm].self, from: UserDefaults.standard.string(forKey: searchesKey) ?? "[]") ?? []
        self.filters = decode([ConsoleSearchFilter].self, from: UserDefaults.standard.string(forKey: filtersKey) ?? "[]") ?? []
    }

    private var searchesKey: String { "\(mode.rawValue)-recent-searches" }
    private var filtersKey: String { "\(mode.rawValue)-recent-filters" }

    func saveSearch(_ search: ConsoleSearchTerm) {
        // If the user changes the type o the search, remove the old ones:
        // we only care about the term.
        searches.removeAll { $0.text == search.text }
        searches.insert(search, at: 0)
        saveSearches()
    }

    func clearRecentSearches() {
        searches = []
        filters = []
        saveSearches()
        saveFilters()
    }

    private func saveSearches() {
        while searches.count > 20 {
            searches.removeLast()
        }
        UserDefaults.standard.set((encode(searches) ?? "[]"), forKey: searchesKey)
    }

    func saveFilter(_ filter: ConsoleSearchFilter) {
        filters.removeAll { type(of: $0.filter) == type(of: filter.filter) }
        filters.insert(filter, at: 0)
        saveFilters()
    }

    private func saveFilters() {
        while filters.count > 20 {
            filters.removeLast()
        }
        UserDefaults.standard.set((encode(filters) ?? "[]"), forKey: filtersKey)
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
