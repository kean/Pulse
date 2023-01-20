// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

final class ConsoleSearchBarViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var tokens: [ConsoleSearchToken] = []
}

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchViewModel: ObservableObject, ConsoleSearchOperationDelegate {
    private var entities: CurrentValueSubject<[NSManagedObject], Never>

    var isViewVisible = false {
        didSet {
            if !isViewVisible {
                operation?.cancel()
                operation = nil
            }
        }
    }

    @Published var options: StringSearchOptions = .default

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []
    @Published private(set) var hasMore = false
    @Published private(set) var isNewResultsButtonShown = false

    @Published private(set)var isSpinnerNeeded = false
    @Published private(set)var isSearching = false
    var hasRecentTokens: Bool { !suggestionsService.recentTokens.isEmpty }

    let searchBar: ConsoleSearchBarViewModel

    var toolbarTitle: String {
        if parameters.isEmpty {
            return "Suggested Filters"
        } else {
            return "\(results.count) results"
        }
    }

    var parameters: ConsoleSearchParameters {
        var tokens = searchBar.tokens
        let searchTerm = searchBar.text.trimmingCharacters(in: .whitespaces)
        if !searchTerm.isEmpty {
            tokens.append(.term(.init(text: searchTerm, options: options)))
        }
        return ConsoleSearchParameters(tokens: tokens)
    }

    private var dirtyDate: Date?
    private var buffer: [ConsoleSearchResultViewModel] = []
    private var operation: ConsoleSearchOperation?
    private var refreshResultsOperation: ConsoleSearchOperation?

    @Published var topSuggestions: [ConsoleSearchSuggestion] = []
    @Published var suggestedScopes: [ConsoleSearchSuggestion] = []

    private let searchService = ConsoleSearchService()
    private let suggestionsService = ConsoleSearchSuggestionsService()

    private let store: LoggerStore
    private let hosts: ManagedObjectsObserver<NetworkDomainEntity>
    private let queue = DispatchQueue(label: "com.github.pulse.console-search-view")
    private var cancellables: [AnyCancellable] = []
    private let context: NSManagedObjectContext

    init(entities: CurrentValueSubject<[NSManagedObject], Never>, store: LoggerStore, searchBar: ConsoleSearchBarViewModel) {
        self.entities = entities
        self.searchBar = searchBar
        self.store = store
        self.context = store.newBackgroundContext()
        self.hosts = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \NetworkDomainEntity.count, ascending: false))

        let text = searchBar.$text
            .map { $0.trimmingCharacters(in: .whitespaces ) }
            .removeDuplicates()

        searchBar.$text.sink {
            if $0.last == "\t" {
                DispatchQueue.main.async {
                    self.applyCurrentFilter()
                }
            }
        }.store(in: &cancellables)

        let didChangeSearchCriteria = Publishers.CombineLatest3(
            text.removeDuplicates(),
            searchBar.$tokens.removeDuplicates(),
            $options.removeDuplicates()
        )
            .map { _, _, _ in }
            .dropFirst()
            .receive(on: DispatchQueue.main)

        didChangeSearchCriteria
            .throttle(for: 0.3, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.didUpdateSearchCriteria()
            }.store(in: &cancellables)

        didChangeSearchCriteria.sink { [weak self] in
            self?.updateSearchTokens()
        }.store(in: &cancellables)

        self.topSuggestions = suggestionsService.makeDefaultTopSuggestions(current: [])
        self.suggestedScopes = suggestionsService.makeDefaultSuggestedScopes()

        entities
            .throttle(for: 3, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.didReloadEntities(for: $0) }
            .store(in: &cancellables)
    }

    // MARK: Search

    private func didUpdateSearchCriteria() {
        isNewResultsButtonShown = false
        startSearch(parameters: parameters)
    }

    private func startSearch(parameters: ConsoleSearchParameters) {
        operation?.cancel()
        operation = nil

        guard !parameters.isEmpty else {
            isSearching = false
            results = []
            return
        }

        isSearching = true
        buffer = []

        // We want to continue showing old results for just a little bit longer
        // to prevent screen from flickering. If the search is slow, we'll just
        // remove the results eventually.
        if !results.isEmpty {
            dirtyDate = Date()
        }

        let operation = ConsoleSearchOperation(objectIDs: entities.value.map(\.objectID), parameters: parameters, service: searchService, context: context)
        operation.delegate = self
        operation.resume()
        self.operation = operation
    }

    // MARK: Refresh Results

    private func didReloadEntities(for entities: [NSManagedObject]) {
        checkForNewSearchMatches(for: entities)
    }

    private func checkForNewSearchMatches(for entities: [NSManagedObject]) {
        guard isViewVisible else {
            return // Off-screen
        }
        guard operation == nil && refreshResultsOperation == nil else {
            return // Let's wait until the next refresh
        }
        guard !isNewResultsButtonShown else {
            return // We already know there are new results
        }
        let operation = ConsoleSearchOperation(objectIDs: entities.map(\.objectID), parameters: parameters, service: searchService, context: context)
        operation.delegate = self
        operation.resume()
        self.refreshResultsOperation = operation
    }

    // MARK: ConsoleSearchOperationDelegate

    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel]) {
        if operation === self.operation {
            if let dirtyDate = dirtyDate {
                self.buffer += results
                if Date().timeIntervalSince(dirtyDate) > 0.25 {
                    self.dirtyDate = nil
                    self.results = buffer
                    self.buffer = []
                }
            } else {
                self.results += results
            }
        } else if operation === self.refreshResultsOperation {
            // If the first element changed, that should be enough of the
            // indicator that there are new search matches. We can assume
            // that the messages are only ever inserted at the top and skip
            // a ton of work.
            if results.first?.entity.objectID !== self.results.first?.entity.objectID {
                withAnimation {
                    self.isNewResultsButtonShown = true
                }
            }
            self.refreshResultsOperation?.cancel()
            self.refreshResultsOperation = nil
        }
    }

    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool) {
        if operation === self.operation {
            self.operation = nil
            isSearching = false
            if dirtyDate != nil {
                self.dirtyDate = nil
                self.results = buffer
            }
            self.hasMore = hasMore
        } else if operation === self.refreshResultsOperation {
            self.refreshResultsOperation = nil
        }
    }

    // MARK: Actions

    func refreshNow() {
        if isNewResultsButtonShown {
            withAnimation {
                isNewResultsButtonShown = false
            }
        }
        startSearch(parameters: parameters)
    }

    func perform(_ suggestion: ConsoleSearchSuggestion) {
        switch suggestion.action {
        case .apply(let token):
            searchBar.text = ""
            searchBar.tokens.append(token)
            suggestionsService.saveRecentToken(token)
        case .autocomplete(let text):
            searchBar.text = text
        }
        updateSearchTokens()
    }

    private func applyCurrentFilter() {
        if let suggestion = topSuggestions.first {
            perform(suggestion)
        }
    }

    func onSubmitSearch() {
        let searchTerm = searchBar.text.trimmingCharacters(in: .whitespaces)
        if !searchTerm.isEmpty {
            searchBar.text = ""
            searchBar.tokens.append(.term(.init(text: searchTerm, options: options)))
        }
    }

    func buttonShowMoreResultsTapped() {
        isSearching = true
        operation?.resume()
    }

    func buttonShowNewlyAddedSearchResultsTapped() {
        refreshNow()
    }

    func buttonClearRecentTokensTapped() {
        suggestionsService.clearRecentTokens()
        updateSearchTokens()
    }

    func prepareForSharing(as output: ShareOutput, _ completion: @escaping (ShareItems?) -> Void) {
        ShareService.share(results.map(\.entity), store: store, as: output, completion)
    }

    // MARK: Suggested Tokens

    private func updateSearchTokens() {
        let hosts = hosts.objects.map(\.value)
        let parameters = self.parameters
        let searchText = searchBar.text.trimmingCharacters(in: .whitespaces)
        let tokens = searchBar.tokens
        let options = self.options

        queue.async {
            let topSuggestions: [ConsoleSearchSuggestion]
            let suggestedScopes: [ConsoleSearchSuggestion]
            if parameters.isEmpty {
                topSuggestions = self.suggestionsService.makeDefaultTopSuggestions(current: tokens)
                suggestedScopes = self.suggestionsService.makeDefaultSuggestedScopes()
            } else {
                topSuggestions = self.suggestionsService.makeTopSuggestions(searchText: searchText, hosts: hosts, current: tokens, options: options)
                suggestedScopes = []
            }
            DispatchQueue.main.async {
                self.topSuggestions = topSuggestions
                self.suggestedScopes = suggestedScopes
            }
        }
    }

    func isActionable(_ suggestion: ConsoleSearchSuggestion) -> Bool {
        suggestion.id == topSuggestions.first?.id
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultViewModel: Identifiable {
    var id: NSManagedObjectID { entity.objectID }
    let entity: NSManagedObject
    let occurrences: [ConsoleSearchOccurrence]
}

struct ConsoleSearchParameters: Equatable, Hashable {
    var filters: [ConsoleSearchFilter] = []
    var scopes: [ConsoleSearchScope] = []
    var terms: [ConsoleSearchTerm] = []

    init(tokens: [ConsoleSearchToken]) {
        for token in tokens {
            switch token {
            case .filter(let filter): self.filters.append(filter)
            case .scope(let scope): self.scopes.append(scope)
            case .term(let string): self.terms.append(string)
            }
        }
        if self.scopes.isEmpty {
            self.scopes = ConsoleSearchScope.allCases
        }
    }

    var isEmpty: Bool {
        filters.isEmpty && terms.isEmpty
    }
}
