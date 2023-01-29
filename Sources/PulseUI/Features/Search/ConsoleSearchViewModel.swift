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
    var hasRecentSearches: Bool { !suggestionsService.recentSearches.isEmpty }

    let searchBar: ConsoleSearchBarViewModel

    var toolbarTitle: String {
        if parameters.isEmpty {
            return "Search"
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

    @Published var suggestionsViewModel: ConsoleSearchSuggestionsViewModel!

    private let searchService = ConsoleSearchService()
    private let suggestionsService = ConsoleSearchSuggestionsService()

    private let store: LoggerStore
    private let index: LoggerStoreIndex
    private let queue = DispatchQueue(label: "com.github.pulse.console-search-view")
    private var cancellables: [AnyCancellable] = []
    private let context: NSManagedObjectContext

    init(entities: CurrentValueSubject<[NSManagedObject], Never>, store: LoggerStore, index: LoggerStoreIndex, searchBar: ConsoleSearchBarViewModel) {
        self.entities = entities
        self.searchBar = searchBar
        self.store = store
        self.index = index
        self.context = store.newBackgroundContext()

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

        entities
            .throttle(for: 3, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.didReloadEntities(for: $0) }
            .store(in: &cancellables)

        self.suggestionsViewModel = makeSuggestions(for: makeContextForSuggestions())
    }

    // MARK: Search

    private func didUpdateSearchCriteria() {
        isNewResultsButtonShown = false
        startSearch(parameters: parameters)
    }

    private func startSearch(parameters: ConsoleSearchParameters) {
        operation?.cancel()
        operation = nil
        hasMore = false

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

        let operation = ConsoleSearchOperation(entities: entities.value, parameters: parameters, service: searchService, context: context)
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
        guard !parameters.isEmpty else {
            return
        }
        let operation = ConsoleSearchOperation(entities: entities, parameters: parameters, service: searchService, context: context)
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
            apply(token)
        case .autocomplete(let text):
            searchBar.text = text
        }
        updateSearchTokens()
    }

    private func apply(_ token: ConsoleSearchToken) {
        searchBar.text = ""
        searchBar.tokens.append(token)
        switch token {
        case .filter(let filter): suggestionsService.saveRecentFilter(filter)
        case .term(let term): suggestionsService.saveRecentSearch(term)
        case .scope: break
        }
    }

    private func applyCurrentFilter() {
        if let suggestion = suggestionsViewModel.topSuggestion {
            perform(suggestion)
        }
    }

    func onSubmitSearch() {
        let searchTerm = searchBar.text.trimmingCharacters(in: .whitespaces)
        if !searchTerm.isEmpty {
            apply(.term(.init(text: searchTerm, options: options)))
        }
    }

    func buttonShowMoreResultsTapped() {
        isSearching = true
        operation?.resume()
    }

    func buttonShowNewlyAddedSearchResultsTapped() {
        refreshNow()
    }

    func buttonClearRecentSearchesTapped() {
        suggestionsService.clearRecentSearches()
        updateSearchTokens()
    }

    func prepareForSharing(as output: ShareOutput, _ completion: @escaping (ShareItems?) -> Void) {
        ShareService.share(results.map(\.entity), store: store, as: output, completion)
    }

    // MARK: Suggested Tokens

    private func updateSearchTokens() {
        let context = makeContextForSuggestions()
        queue.async {
            let viewModel = self.makeSuggestions(for: context)
            DispatchQueue.main.async {
                self.suggestionsViewModel = viewModel
            }
        }
    }

    private func makeContextForSuggestions() -> ConsoleSearchSuggestionsContext {
        ConsoleSearchSuggestionsContext(
            searchText: searchBar.text.trimmingCharacters(in: .whitespaces),
            index: index,
            parameters: parameters
        )
    }

    private func makeSuggestions(for context: ConsoleSearchSuggestionsContext) -> ConsoleSearchSuggestionsViewModel {
        let service = suggestionsService
        if context.searchText.isEmpty && context.parameters.filters.isEmpty && context.parameters.terms.isEmpty {
            return ConsoleSearchSuggestionsViewModel(
                searches: service.makeRecentSearhesSuggestions(),
                filters: service.makeTopSuggestions(context: context),
                scopes: service.makeScopesSuggestions(context: context)
            )
        } else {
            return ConsoleSearchSuggestionsViewModel(
                searches: [],
                filters: service.makeTopSuggestions(context: context),
                scopes: []
            )
        }
    }

    func isActionable(_ suggestion: ConsoleSearchSuggestion) -> Bool {
        suggestionsViewModel.topSuggestion?.id == suggestion.id
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultViewModel: Identifiable {
    var id: ConsoleSearchResultKey { ConsoleSearchResultKey(id: entity.objectID) }
    let entity: NSManagedObject
    let occurrences: [ConsoleSearchOccurrence]
}

struct ConsoleSearchResultKey: Hashable{
    let id: NSManagedObjectID
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
    }

    var isEmpty: Bool {
        filters.isEmpty && terms.isEmpty
    }
}
