// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchSuggestionsService {

    private(set) var recentTokens: [ConsoleSearchToken] = []

    init() {
        self.recentTokens = getRecentTokens()
    }

    // MARK: - Top Suggestions

    func makeTopSuggestions(searchText: String, hosts: [String], current: [ConsoleSearchToken]) -> [ConsoleSearchSuggestion] {
        guard !searchText.isEmpty else {
            return Array(makeDefaultTopSuggestions(current: current).prefix(3))
        }

        var filters = Parsers.filters
            .compactMap { try? $0.parse(searchText) }
            .sorted(by: { $0.1 > $1.1 }) // Sort by confidence

        // Auto-complete hosts (TODO: refactor)
        var hasHostsFilter = false
        filters = filters.flatMap {
            guard case .host(let filter) = $0.0 else { return [$0] }
            hasHostsFilter = true
            let confidence = $0.1
            return autocompleteHosts(for: filter, hosts: hosts).map { (.host($0), confidence) }
        }
        if !hasHostsFilter {
            let hosts = autocomplete(host: searchText, hosts: hosts)
            filters += hosts.map { (ConsoleSearchFilter.host(.init(values: [$0])), 0.8) }
        }

        let scopes: [(ConsoleSearchScope, Confidence)] = ConsoleSearchScope.allEligibleScopes.compactMap {
            guard let confidence = try? Parsers.filterName($0.title).parse(searchText) else { return nil }
            return ($0, confidence)
        }

        let allSuggestions = filters.map { (makeSuggestion(for: $0.0), $0.1) } +
        scopes.map { (makeSuggestion(for: $0.0), $0.1) }

        let plainSearchSuggestion = ConsoleSearchSuggestion(text: {
            AttributedString("Contains: ") { $0.foregroundColor = .primary } +
            AttributedString(searchText) { $0.foregroundColor = .blue }
        }(), action: .apply(.term(.init(text: searchText, options: .default))))

        let topSuggestions = Array(allSuggestions
            .sorted(by: { $0.1 > $1.1 }) // Sort by confidence
            .map { $0.0 }.prefix(3))
        if let first = topSuggestions.first,
           first.isToken || first.text.description.hasPrefix(searchText) {
            return topSuggestions + [plainSearchSuggestion]
        } else {
            return [plainSearchSuggestion] + topSuggestions
        }
    }

    // TODO: do it on the Parser level
    private func autocompleteHosts(for filter: ConsoleSearchFilterHost, hosts: [String]) -> [ConsoleSearchFilterHost] {
        guard let value = filter.values.first,
              filter.values.count == 1 else { return [filter] }
        let hosts = autocomplete(host: value, hosts: hosts)
        let filters = hosts.map { ConsoleSearchFilterHost(values: [$0]) }
        let prefix = Array(filters.prefix(2))
        if prefix.contains(where: { $0.values == filter.values }) {
            return prefix // Already has a full match
        }
        return prefix + [filter]
    }

    private func autocomplete(host target: String, hosts: [String]) -> [String] {
        let target = target.lowercased()
        var topHosts: [String] = []
        var otherHosts: [String] = []
        for host in hosts {
            if host.hasPrefix(target) {
                topHosts.append(host)
            } else if host.contains(target) {
                otherHosts.append(host)
            }
        }
        return topHosts + otherHosts
    }

    // Shows recent tokens and unused default tokens.
    func makeDefaultTopSuggestions(current: [ConsoleSearchToken]) -> [ConsoleSearchSuggestion] {
        var tokens = recentTokens
        let defaultTokens = [
            ConsoleSearchFilter.statusCode(.init(values: [])),
            ConsoleSearchFilter.method(.init(values: [])),
            ConsoleSearchFilter.host(.init(values: [])),
            ConsoleSearchFilter.path(.init(values: []))
        ].map { ConsoleSearchToken.filter($0) }
        for token in defaultTokens where !tokens.contains(where: { $0.isSameType(as: token) }) {
            tokens.append(token)
        }
        return Array(tokens.filter { token in
            !current.contains(where: { $0.isSameType(as: token) })
        }.map(makeSuggestion).prefix(8))
    }

    func makeDefaultSuggestedScopes() -> [ConsoleSearchSuggestion] {
        ConsoleSearchScope.allEligibleScopes.map(makeSuggestion)
    }

    private func makeSuggestion(for token: ConsoleSearchToken) -> ConsoleSearchSuggestion {
        switch token {
        case .filter(let filter): return makeSuggestion(for: filter)
        case .scope(let scope): return makeSuggestion(for: scope)
        case .term(let term): return makeSuggestion(for: term)
        }
    }

    private func makeSuggestion(for filter: ConsoleSearchFilter) -> ConsoleSearchSuggestion {
        var string = AttributedString(filter.name + ": ") { $0.foregroundColor = .primary }
        let values = filter.valuesDescriptions
        if values.isEmpty {
            string.append(filter.valueExample) { $0.foregroundColor = .secondary }
        } else {
            for (index, description) in values.enumerated() {
                string.append(description) { $0.foregroundColor = .blue }
                if index < values.endIndex - 1 {
                    string.append(", ") { $0.foregroundColor = .secondary }
                }
            }
        }
        return ConsoleSearchSuggestion(text: string, action: {
            if values.isEmpty {
                return .autocomplete(filter.name + ": ")
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
            AttributedString("\(term.options.title): ") { $0.foregroundColor = .primary } +
            AttributedString(term.text) { $0.foregroundColor = .blue }
        }(), action: .apply(.term(term)))
    }


    // MARK: - Recent Tokens

    private func getRecentTokens() -> [ConsoleSearchToken] {
        ConsoleSettings.shared.recentSearches.data(using: .utf8).flatMap {
            try? JSONDecoder().decode([ConsoleSearchToken].self, from: $0)
        } ?? []
    }

    func saveRecentToken(_ token: ConsoleSearchToken) {
        var tokens = self.recentTokens
        while let index = tokens.firstIndex(where: { $0 == token }) {
            tokens.remove(at: index)
        }
        var count = 0
        tokens.removeAll(where: {
            if $0.isSameType(as: token) {
                count += 1
                if count == 3 {
                    return true
                }
            }
            return false

        })
        if tokens.count > 15 {
            tokens.removeLast(tokens.count - 15)
        }
        tokens.insert(token, at: 0)

        self.recentTokens = tokens
        saveRecentTokens()
    }

    func clearRecentTokens() {
        recentTokens = []
        saveRecentTokens()
    }

    private func saveRecentTokens() {
        guard let data = (try? JSONEncoder().encode(recentTokens)),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        ConsoleSettings.shared.recentSearches = string
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestion: Identifiable {
    let id = UUID()
    let text: AttributedString
    var action: Action

    var isToken: Bool {
        guard case .apply = action else { return false }
        return true
    }

    enum Action {
        case apply(ConsoleSearchToken)
        case autocomplete(String)
    }
}
