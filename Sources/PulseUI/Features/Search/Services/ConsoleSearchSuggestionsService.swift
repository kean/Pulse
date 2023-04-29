// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, *)
struct ConsoleSearchSuggestionsViewModel {
    let searches: [ConsoleSearchSuggestion]
    let filters: [ConsoleSearchSuggestion]

    func getSuggestion(withID id: UUID) -> ConsoleSearchSuggestion? {
        (searches + filters).first { $0.id == id }
    }
}

struct ConsoleSearchSuggestionsContext {
    let searchText: String
    let index: LoggerStoreIndex
    let parameters: ConsoleSearchParameters

    var isEmpty: Bool {
        searchText.isEmpty && parameters.filters.isEmpty && parameters.terms.isEmpty
    }

    var hasLogFilters: Bool {
        parameters.filters.contains { $0.filter is (any ConsoleSearchLogFilterProtocol) }
    }

    var hasNetworkFilters: Bool {
        parameters.filters.contains { $0.filter is (any ConsoleSearchNetworkFilterProtocol) }
    }
}

@available(iOS 15, *)
final class ConsoleNetworkSearchSuggestionsService {
    let recents: ConsoleSearchRecentSearchesStore
    let mode: ConsoleMode

    init(mode: ConsoleMode) {
        self.mode = mode
        self.recents = ConsoleSearchRecentSearchesStore(mode: mode)
    }

    func makeSuggestions(for context: ConsoleSearchSuggestionsContext) -> ConsoleSearchSuggestionsViewModel {
        ConsoleSearchSuggestionsViewModel(searches: makeRecentSearches(context), filters: makeFilters(context))
    }

    // MARK: Searches

    // Show recent searches only if nothing is selected.
    private func makeRecentSearches(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        guard context.isEmpty else { return [] }
        let searches = recents.searches.prefix(2).map(makeSuggestion)
        let filters = recents.filters.prefix(4).map(makeSuggestion)
        return Array((searches + filters).prefix(4))
    }

    // MARK: Filters

    private func makeFilters(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        if context.isEmpty {
            return makeDefaultFilters(context)
        } else {
            return parse(makeFilterParsers(context), context)
        }
    }

    private func makeFilterParsers(_ context: ConsoleSearchSuggestionsContext) -> [Parser<[(ConsoleSearchFilter, Confidence)]>] {
        ((mode.hasLogs && !context.hasNetworkFilters) ? Parsers.makeLogsFilters(context: context) : []) +
        ((mode.hasNetwork && !context.hasLogFilters) ? Parsers.makeNetworkFilters(context: context) : [])
    }

    private func parse(_ filters: [Parser<[(ConsoleSearchFilter, Confidence)]>], _ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        var filters = filters.compactMap { try? $0.parse(context.searchText) }
            .flatMap { $0 }
            .filter { $0.1 > 0.5 }
            .sorted(by: { $0.1 > $1.1 }) // Sort by confidence
            .map(\.0)
        var encountered = Set<ConsoleSearchFilter>()
        filters = filters.filter {
            guard !encountered.contains($0) else { return false }
            encountered.insert($0)
            return true
        }
        return Array(filters.map(makeSuggestion).prefix(3))
    }

    private func makeDefaultFilters(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        (mode.hasLogs ? makeDefaultLogsFilters(context) : []) +
        (mode.hasNetwork ? makeDefaultNetworkFilters(context) : [])
    }

    private func makeDefaultLogsFilters(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        return [
            ConsoleSearchFilter.level(.init(values: [])),
            ConsoleSearchFilter.label(.init(values: [])),
            ConsoleSearchFilter.file(.init(values: [])),
        ].map(makeSuggestion)
    }

    private func makeDefaultNetworkFilters(_ context: ConsoleSearchSuggestionsContext) -> [ConsoleSearchSuggestion] {
        return [
            ConsoleSearchFilter.statusCode(.init(values: [])),
            ConsoleSearchFilter.method(.init(values: [])),
            ConsoleSearchFilter.host(.init(values: [])),
            ConsoleSearchFilter.path(.init(values: []))
        ].map(makeSuggestion)
    }

    // MARK: Helpers

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

    private func makeSuggestion(for term: ConsoleSearchTerm) -> ConsoleSearchSuggestion {
        ConsoleSearchSuggestion(text: {
            AttributedString("\(term.options.title) ") { $0.foregroundColor = .primary } +
            AttributedString(term.text) { $0.foregroundColor = .blue }
        }(), action: .apply(.term(term)))
    }
}

@available(iOS 15, *)
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
