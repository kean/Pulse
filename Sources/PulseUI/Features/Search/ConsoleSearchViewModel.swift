// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

protocol ConsoleEntitiesSource {
    var events: PassthroughSubject<ConsoleUpdateEvent, Never> { get }
    var entities: [NSManagedObject] { get }
}

#if os(iOS) || os(macOS) || os(visionOS)

final class ConsoleSearchBarViewModel: ObservableObject {
    @Published var text: String = ""
}

@available(iOS 15, visionOS 1.0, *)
final class ConsoleSearchViewModel: ObservableObject, ConsoleSearchOperationDelegate {
    var isSearchActive: Bool = false {
        didSet {
            guard oldValue != isSearchActive else { return }
            if !isSearchActive {
                searchService.clearCache()
                operation?.cancel()
                operation = nil
            }
        }
    }

    @Published var options: StringSearchOptions = .default
    @Published var scopes: Set<ConsoleSearchScope> = []

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []
    @Published private(set) var hasMore = false
    @Published private(set) var isNewResultsButtonShown = false

    @Published private(set) var isSpinnerNeeded = false
    @Published private(set) var isSearching = false

    var hasRecentSearches: Bool { !recents.searches.isEmpty }

    let searchBar: ConsoleSearchBarViewModel

    var toolbarTitle: String {
        if parameters.isEmpty {
            return "Search"
        } else {
            return "\(results.count)\(hasMore ? "+" : "") results"
        }
    }

    var parameters: ConsoleSearchParameters {
        var term: ConsoleSearchTerm?
        let searchTerm = searchBar.text.trimmingCharacters(in: .whitespaces)
        if !searchTerm.isEmpty {
            term = ConsoleSearchTerm(text: searchTerm, options: options)
        }
        return ConsoleSearchParameters(term: term, scopes: scopes)
    }

    var allScopes: [ConsoleSearchScope] {
        (environment.mode.hasLogs ? ConsoleSearchScope.messageScopes : []) +
        (environment.mode.hasNetwork ? ConsoleSearchScope.networkScopes : [])
    }

    private var dirtyDate: Date?
    private var buffer: [ConsoleSearchResultViewModel] = []
    private var operation: ConsoleSearchOperation?
    private var refreshResultsOperation: ConsoleSearchOperation?

    private let recents: ConsoleSearchRecentSearchesStore
    @Published private(set) var suggestionsViewModel: ConsoleSearchSuggestionsViewModel!

    private let source: ConsoleEntitiesSource
    private let searchService = ConsoleSearchService()

    private let environment: ConsoleEnvironment
    private let store: LoggerStore
    private let index: LoggerStoreIndex
    private var cancellables: [AnyCancellable] = []
    private let context: NSManagedObjectContext

    init(environment: ConsoleEnvironment, source: ConsoleEntitiesSource, searchBar: ConsoleSearchBarViewModel) {
        self.environment = environment
        self.store = environment.store
        self.index = environment.index
        self.recents = ConsoleSearchRecentSearchesStore(mode: environment.mode)
        self.source = source
        self.searchBar = searchBar

        self.context = store.newBackgroundContext()
        self.scopes = Set(allScopes)

        let text = searchBar.$text
            .map { $0.trimmingCharacters(in: .whitespaces ) }
            .removeDuplicates()

        let didChangeSearchCriteria = Publishers.CombineLatest3(
            text.removeDuplicates(),
            $options.removeDuplicates(),
            $scopes
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

        source.events.sink { [weak self] in
            self?.didReceive($0)
        }.store(in: &cancellables)

        environment.$mode.sink { [weak self] in
            self?.configure(mode: $0)
        }.store(in: &cancellables)
    }

    private func configure(mode: ConsoleMode) {
        self.suggestionsViewModel = getRecentSearches()
        DispatchQueue.main.async {
            self.refreshNow()
        }
    }

    private func didReceive(_ event: ConsoleUpdateEvent) {
        switch event {
        case .refresh:
            refreshNow()
        case .update:
            checkForNewSearchMatches(for: source.entities)
        }
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

        let operation = ConsoleSearchOperation(entities: source.entities, parameters: parameters, service: searchService, context: context)
        operation.delegate = self
        operation.resume()
        self.operation = operation
    }

    // MARK: Refresh Results

    private func didReloadEntities(for entities: [NSManagedObject]) {
        checkForNewSearchMatches(for: entities)
    }

    private func checkForNewSearchMatches(for entities: [NSManagedObject]) {
        guard isSearchActive else {
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

    private func apply(_ term: ConsoleSearchTerm) {
        searchBar.text = term.text
        options = term.options
        recents.saveSearch(term)
    }

    func onSubmitSearch() {
#if os(macOS)
        if let suggestionID = UUID(uuidString: searchBar.text),
           let suggestion = suggestionsViewModel.getSuggestion(withID: suggestionID) {
            perform(suggestion)
            return
        }
#endif
        let searchTerm = searchBar.text.trimmingCharacters(in: .whitespaces)
        if !searchTerm.isEmpty {
            recents.saveSearch(.init(text: searchTerm, options: options))
        }
    }

    func buttonShowNewlyAddedSearchResultsTapped() {
        refreshNow()
    }

    func buttonClearRecentSearchesTapped() {
        recents.clearRecentSearches()
        updateSearchTokens()
    }

    func didScroll(to result: ConsoleSearchResultViewModel) {
        guard results.count > 3 && results[results.endIndex - 2].entity.objectID == result.entity.objectID else {
            return
        }
        guard !isSearching && hasMore else {
            return
        }
        isSearching = true
        operation?.resume() // Load more
    }

    // MARK: Suggested Tokens

    private func updateSearchTokens() {
        let searchText = searchBar.text.trimmingCharacters(in: .whitespaces)
        if searchText.isEmpty {
            self.suggestionsViewModel = getRecentSearches()
        } else {
            self.suggestionsViewModel = ConsoleSearchSuggestionsViewModel(searches: [])
        }
    }

    private func getRecentSearches() -> ConsoleSearchSuggestionsViewModel {
        let recentSearches = recents.searches.prefix(3).map { term in
            ConsoleSearchSuggestion(text: {
                AttributedString("\(term.options.title) ") { $0.foregroundColor = .primary } +
                AttributedString(term.text) { $0.foregroundColor = .accentColor }
            }(), action: .apply(term))
        }
        return ConsoleSearchSuggestionsViewModel(searches: recentSearches)
    }
}

@available(iOS 15, visionOS 1.0, *)
struct ConsoleSearchResultViewModel: Identifiable {
    var id: ConsoleSearchResultKey { ConsoleSearchResultKey(id: entity.objectID) }
    let entity: NSManagedObject
    let occurrences: [ConsoleSearchOccurrence]
}

struct ConsoleSearchResultKey: Hashable {
    let id: NSManagedObjectID
}

struct ConsoleSearchParameters: Equatable, Hashable {
    var scopes: [ConsoleSearchScope] = []
    var term: ConsoleSearchTerm?

    init(term: ConsoleSearchTerm?, scopes: Set<ConsoleSearchScope>) {
        self.term = term
        self.scopes = Array(scopes)
    }

    var isEmpty: Bool {
        term == nil
    }
}

@available(iOS 15, visionOS 1.0, *)
struct ConsoleSearchSuggestionsViewModel {
    let searches: [ConsoleSearchSuggestion]

    func getSuggestion(withID id: UUID) -> ConsoleSearchSuggestion? {
        (searches).first { $0.id == id }
    }
}

@available(iOS 15, visionOS 1.0, *)
struct ConsoleSearchSuggestion: Identifiable {
    let id = UUID()
    let text: AttributedString
    var action: Action

    enum Action {
        case apply(ConsoleSearchTerm)
        case autocomplete(String)
    }
}

#endif
