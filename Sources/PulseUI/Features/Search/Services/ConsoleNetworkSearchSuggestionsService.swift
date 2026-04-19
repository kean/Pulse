// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleSearchSuggestionsViewModel {
    package let searches: [ConsoleSearchSuggestion]
    package let filters: [ConsoleSearchSuggestion]

    package func getSuggestion(withID id: UUID) -> ConsoleSearchSuggestion? {
        (searches + filters).first { $0.id == id }
    }
}

package struct ConsoleSearchSuggestionsContext {
    package let searchText: String
    package let index: LoggerStoreIndex
    package let parameters: ConsoleSearchParameters

    package init(searchText: String, index: LoggerStoreIndex, parameters: ConsoleSearchParameters) {
        self.searchText = searchText
        self.index = index
        self.parameters = parameters
    }

    package var isEmpty: Bool {
        searchText.isEmpty && parameters.terms.isEmpty
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package final class ConsoleNetworkSearchSuggestionsService {
    package let recents: ConsoleSearchRecentSearchesStore
    package let mode: ConsoleMode

    package init(mode: ConsoleMode) {
        self.mode = mode
        self.recents = ConsoleSearchRecentSearchesStore(mode: mode)
    }

    package func makeSuggestions(for context: ConsoleSearchSuggestionsContext) -> ConsoleSearchSuggestionsViewModel {
        ConsoleSearchSuggestionsViewModel(searches: makeRecentSearches(context), filters: makeFilters(context))
    }

    // MARK: Searches

    // Show recent searches only if nothing is selected.
    private func makeRecentSearches(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        guard context.isEmpty else { return [] }
        return Array(recents.searches.prefix(4).map(makeSuggestion))
    }

    // MARK: Filters

    private func makeFilters(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        guard !context.searchText.isEmpty else { return [] }
        let results = ConsoleSearchFilterMatcher.suggestions(
            for: context.searchText,
            index: context.index,
            mode: mode,
            hasLogFilters: false,
            hasNetworkFilters: false
        )
        var filters = results
            .filter { $0.1 > 0.5 }
            .sorted(by: { $0.1 > $1.1 })
            .map(\.0)
        var encountered = Set<ConsoleSearchToken>()
        filters = filters.filter {
            guard !encountered.contains($0) else { return false }
            encountered.insert($0)
            return true
        }
        return Array(filters.map { makeSuggestion(for: $0, searchText: context.searchText) }.prefix(3))
    }

    // MARK: Helpers

    private func makeSuggestion(for token: ConsoleSearchToken, searchText: String) -> ConsoleSearchSuggestion {
        let filter = ConsoleSearchFilterSuggestion(token: token, searchText: searchText, match: token.defaultMatch)
        return ConsoleSearchSuggestion(action: .applyFilter(filter))
    }

    private func makeSuggestion(for term: ConsoleSearchTerm) -> ConsoleSearchSuggestion {
        ConsoleSearchSuggestion(action: .applyTerm(term))
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleSearchSuggestion: Identifiable {
    package let id = UUID()
    package var action: Action

    package init(action: Action) {
        self.action = action
    }

    package enum Action {
        case applyTerm(ConsoleSearchTerm)
        case applyFilter(ConsoleSearchFilterSuggestion)
    }
}

package struct ConsoleSearchFilterSuggestion: Hashable {
    package let token: ConsoleSearchToken
    package let searchText: String
    package var match: StringSearchOptions

    package init(token: ConsoleSearchToken, searchText: String, match: StringSearchOptions) {
        self.token = token
        self.searchText = searchText
        self.match = match
    }

    package func makeCustomFilter() -> ConsoleCustomFilter? {
        guard var filter = token.makeCustomFilter() else { return nil }
        filter.match = match
        return filter
    }
}

#endif
