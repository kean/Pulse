// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, visionOS 1.0, *)
struct ConsoleSearchSuggestionsViewModel {
    let searches: [ConsoleSearchSuggestion]

    func getSuggestion(withID id: UUID) -> ConsoleSearchSuggestion? {
        (searches).first { $0.id == id }
    }
}

struct ConsoleSearchSuggestionsContext {
    let searchText: String
    let index: LoggerStoreIndex
    let parameters: ConsoleSearchParameters

    var isEmpty: Bool {
        searchText.isEmpty && parameters.terms.isEmpty
    }
}

@available(iOS 15, visionOS 1.0, *)
final class ConsoleNetworkSearchSuggestionsService {
    let recents: ConsoleSearchRecentSearchesStore
    let mode: ConsoleMode

    init(mode: ConsoleMode) {
        self.mode = mode
        self.recents = ConsoleSearchRecentSearchesStore(mode: mode)
    }

    func makeSuggestions(for context: ConsoleSearchSuggestionsContext) -> ConsoleSearchSuggestionsViewModel {
        ConsoleSearchSuggestionsViewModel(searches: makeRecentSearches(context))
    }

    // MARK: Searches

    // Show recent searches only if nothing is selected.
    private func makeRecentSearches(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        guard context.isEmpty else { return [] }
        let searches = recents.searches.prefix(2).map(makeSuggestion)
        return Array((searches).prefix(4))
    }

    // MARK: Helpers

    private func makeSuggestion(for term: ConsoleSearchTerm) -> ConsoleSearchSuggestion {
        ConsoleSearchSuggestion(text: {
            AttributedString("\(term.options.title) ") { $0.foregroundColor = .primary } +
            AttributedString(term.text) { $0.foregroundColor = .accentColor }
        }(), action: .apply(.term(term)))
    }
}

@available(iOS 15, visionOS 1.0, *)
struct ConsoleSearchSuggestion: Identifiable {
    let id = UUID()
    let text: AttributedString
    var action: Action

    enum Action {
        case apply(ConsoleSearchToken)
        case autocomplete(String)
    }
}

#endif
