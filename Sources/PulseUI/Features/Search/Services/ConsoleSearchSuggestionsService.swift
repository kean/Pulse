// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestionsViewModel {
    let searches: [ConsoleSearchSuggestion]
    let filters: [ConsoleSearchSuggestion]
    let scopes: [ConsoleSearchSuggestion]

    var topSuggestion: ConsoleSearchSuggestion? {
        searches.first ?? filters.first
    }
}

struct ConsoleSearchSuggestionsContext {
    let searchText: String
    let hosts: Set<String>
    let parameters: ConsoleSearchParameters
}

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchSuggestionsService {
    private(set) var recentSearches: [ConsoleSearchTerm]
    private(set) var recentFilters: [ConsoleSearchFilter]

    init() {
        self.recentSearches = decode([ConsoleSearchTerm].self, from: ConsoleSettings.shared.recentSearches) ?? []
        self.recentFilters = decode([ConsoleSearchFilter].self, from: ConsoleSettings.shared.recentFilters) ?? []
    }

    func makeRecentSearhesSuggestions() -> [ConsoleSearchSuggestion] {
        recentSearches.map(makeSuggestion)
    }

    func makeScopesSuggestions(context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        let selectedScopes = Set(context.parameters.scopes)
        return ConsoleSearchScope.allEligibleScopes
            .filter { !selectedScopes.contains($0) }
            .map(makeSuggestion)
    }

    func makeTopSuggestions(context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        guard !context.searchText.isEmpty else {
            guard context.parameters.isEmpty else {
                return []
            }
            return makeDefaultTopSuggestions(context: context)
        }

        let filters = Parsers.makeFilters(context: context)
            .compactMap { try? $0.parse(context.searchText) }
            .flatMap { $0 }
            .filter { $0.1 > 0.5 }
            .sorted(by: { $0.1 > $1.1 }) // Sort by confidence

        return Array(filters.sorted(by: { $0.1 > $1.1 })
            .map { makeSuggestion(for: $0.0) }
            .prefix(3))
    }

    // Shows recent tokens and unused default tokens.
    func makeDefaultTopSuggestions(context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        var filters = recentFilters
        let defaultFilters = [
            ConsoleSearchFilter.statusCode(.init(values: [])),
            ConsoleSearchFilter.method(.init(values: [])),
            ConsoleSearchFilter.host(.init(values: [])),
            ConsoleSearchFilter.path(.init(values: []))
        ]
        for filter in defaultFilters where !filters.contains(where: {
            $0.isSameType(as: filter)
        }) {
            filters.append(filter)
        }
        return Array(filters.filter { filter in
            !context.parameters.filters.contains(where: {
                $0.isSameType(as: filter)
            })
        }.map(makeSuggestion).prefix(7))
    }

    private func makeSuggestion(for filter: ConsoleSearchFilter) -> ConsoleSearchSuggestion {
        var string = AttributedString(filter.filter.name + " ") { $0.foregroundColor = .primary }
        let values = filter.filter.values
        let isExample = values.isEmpty
        let descriptions = !isExample ? values.map(\.description) : filter.filter.valueExamples
        for (index, description) in descriptions.enumerated() {
            string.append(description) { $0.foregroundColor = isExample ? .secondary.opacity(0.8) : .blue }
            if index < descriptions.endIndex - 1 {
                string.append(", ") { $0.foregroundColor = isExample ? .separator : .secondary }
            }
        }
        return ConsoleSearchSuggestion(text: string, action: {
            if values.isEmpty {
                return .autocomplete(filter.filter.name + " ")
            } else {
                return .apply(.filter(filter))
            }
        }())
    }

    private func makeSuggestion(for scope: ConsoleSearchScope) -> ConsoleSearchSuggestion {
        var string = AttributedString("Search in ") { $0.foregroundColor = .primary }
        string.append(scope.title) { $0.foregroundColor = .blue }
        let token = ConsoleSearchToken.scope(scope)
        return ConsoleSearchSuggestion(text: string, action: .apply(token))
    }

    private func makeSuggestion(for term: ConsoleSearchTerm) -> ConsoleSearchSuggestion {
        ConsoleSearchSuggestion(text: {
            AttributedString("\(term.options.title) ") { $0.foregroundColor = .primary } +
            AttributedString(term.text) { $0.foregroundColor = .blue }
        }(), action: .apply(.term(term)))
    }

    // MARK: - Recent Searches

    func saveRecentSearch(_ search: ConsoleSearchTerm) {
        // If the user changes the type o the search, remove the old ones:
        // we only care about the term.
        recentSearches.removeAll { $0.text == search.text }
        recentSearches.insert(search, at: 0)
        while recentSearches.count > 20 {
            recentSearches.removeLast()
        }
        saveRecentSearches()
    }

    func clearRecentSearches() {
        recentSearches = []
        saveRecentSearches()

        recentFilters = []
        saveRecentFilters()
    }

    private func saveRecentSearches() {
        ConsoleSettings.shared.recentSearches = encode(recentSearches) ?? "[]"
    }

    // MARK: - Recent Filters

    func saveRecentFilter(_ filter: ConsoleSearchFilter) {
        recentFilters.removeAll { $0 == filter }
        var count = 0
        recentFilters.removeAll(where: {
            if type(of: $0.filter) == type(of: filter) {
                count += 1
                if count == 3 {
                    return true
                }
            }
            return false
        })
        while recentFilters.count > 20 {
            recentFilters.removeLast()
        }
        recentFilters.insert(filter, at: 0)
    }

    private func saveRecentFilters() {
        ConsoleSettings.shared.recentFilters = encode(recentFilters) ?? "[]"
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestion: Identifiable {
    let id = UUID()
    let text: AttributedString
    var action: Action

    enum Action {
        case apply(ConsoleSearchToken)
        case autocomplete(String)
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
