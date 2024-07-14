// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import SwiftUI

final class ConsoleSearchRecentSearchesStore {
    private let mode: ConsoleMode

    private(set) var searches: [ConsoleSearchTerm] = []

    init(mode: ConsoleMode) {
        self.mode = mode

        self.searches = decode([ConsoleSearchTerm].self, from: UserDefaults.standard.string(forKey: searchesKey) ?? "[]") ?? []
    }

    private var searchesKey: String { "\(mode.rawValue)-recent-searches" }

    func saveSearch(_ search: ConsoleSearchTerm) {
        // If the user changes the type o the search, remove the old ones:
        // we only care about the term.
        searches.removeAll { $0.text == search.text }
        searches.insert(search, at: 0)
        saveSearches()
    }

    func clearRecentSearches() {
        searches = []
        saveSearches()
    }

    private func saveSearches() {
        while searches.count > 20 {
            searches.removeLast()
        }
        UserDefaults.standard.set((encode(searches) ?? "[]"), forKey: searchesKey)
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
