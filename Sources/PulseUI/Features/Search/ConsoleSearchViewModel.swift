// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS) || os(macOS) || os(visionOS)

final class ConsoleSearchBarViewModel: ObservableObject {
    @Published var text: String = ""
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
final class ConsoleSearchViewModel: ObservableObject, ConsoleSearchSessionDelegate {
    @Published var isSearching: Bool = false {
        didSet {
            guard oldValue != isSearching else { return }
            if !isSearching {
                session?.cancel()
                session = nil
                searchBar.text = ""
                // Don't reset filters, scopes, or options: filters are part of
                // the main list state and persist across search sessions, and
                // scopes/options are user preferences.
            }
        }
    }

    @Published var options: StringSearchOptions = .default
    @Published var scopes: Set<ConsoleSearchScope> = []
    @Published private(set) var savedDefaultScopes: Set<ConsoleSearchScope> = []

    @Published var editingFilterState: EditingFilterState?

    struct EditingFilterState: Identifiable {
        var id: UUID { filter.id }
        var filter: ConsoleCustomFilter
        var token: ConsoleSearchToken
    }

    func applyEditedFilter(_ filter: ConsoleCustomFilter) {
        guard let state = editingFilterState else { return }
        applyToken(state.token, filter: filter)
    }

    private func applyToken(_ token: ConsoleSearchToken, filter: ConsoleCustomFilter?) {
        searchBar.text = ""
        var criteria = filters.criteria
        token.apply(to: &criteria, filter: filter)
        filters.criteria = criteria
    }

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []
    @Published private(set) var hasMore = false
    @Published private(set) var newResultsCount = 0
    var isNewResultsButtonShown: Bool { newResultsCount > 0 }

    @Published private(set) var isSpinnerNeeded = false
    @Published private(set) var isPerformingSearch = false

    /// Matches from sessions outside the active selection. Populated after the
    /// primary search exhausts; empty when the user is already searching every
    /// session.
    @Published private(set) var extendedResults: [ConsoleSearchResultViewModel] = []
    @Published private(set) var hasMoreExtended = false
    @Published private(set) var isPerformingExtendedSearch = false

    var hasRecentSearches: Bool { !recents.searches.isEmpty }

    let searchBar: ConsoleSearchBarViewModel
    let filters: ConsoleFiltersViewModel

    var toolbarTitle: String {
        if parameters.isEmpty {
            return "Search"
        }
        let base = "\(results.count)\(hasMore ? "+" : "") results"
        return isPerformingSearch ? "\(base) (searching…)" : base
    }

    var parameters: ConsoleSearchParameters {
        let searchTerm = searchBar.text.trimmingCharacters(in: .whitespaces)
        var params = ConsoleSearchParameters()
        if !searchTerm.isEmpty {
            params.terms.append(.init(text: searchTerm, options: options))
        }
        params.scopes = Array(scopes)
        return params
    }

    var allScopes: [ConsoleSearchScope] {
        ConsoleSearchScope.allScopes(for: environment.mode)
    }

    var availableLogScopes: [ConsoleSearchScope] {
        environment.mode.hasLogs ? ConsoleSearchScope.messageScopes : []
    }

    var availableNetworkScopes: [ConsoleSearchScope] {
        environment.mode.hasNetwork ? ConsoleSearchScope.networkScopes : []
    }

    var defaultScopes: [ConsoleSearchScope] {
        isDeepSearch ? allScopes : ConsoleSearchScope.defaultScopes(for: environment.mode)
    }

    private var session: ConsoleSearchSession?
    /// True from the moment a session is created until its first batch (or
    /// `finished` with no batches) lands. Lets us atomically replace the
    /// previous session's results instead of appending to them.
    private var isAwaitingFirstResults = false

    private var recents: ConsoleSearchRecentSearchesStore { suggestionsService.recents }
    private var suggestionsService: ConsoleNetworkSearchSuggestionsService!
    @Published private(set) var suggestionsViewModel: ConsoleSearchSuggestionsViewModel!

    let environment: ConsoleEnvironment
    private let store: LoggerStoreProtocol
    private let index: LoggerStoreIndex
    private var cancellables: [AnyCancellable] = []
    private var isDeepSearch = false
    private var configuredMode: ConsoleMode?

    init(
        environment: ConsoleEnvironment,
        searchBar: ConsoleSearchBarViewModel,
        isDeepSearch: Bool = false
    ) {
        self.environment = environment
        self.store = environment.store
        self.index = environment.index
        self.searchBar = searchBar
        self.filters = environment.filters
        self.isDeepSearch = isDeepSearch

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

        searchBar.$text
            .sink { [weak self] in self?.handleTab(in: $0) }
            .store(in: &cancellables)

        // Filter changes used to reach us via the list VM's `.refresh` event,
        // which piggy-backed on the data source's FRC refetch. The session now
        // owns its own fetch, so we observe filters directly and rebuild.
        // `@Published` fires in `willSet`, so hop to the main queue before
        // reading `filters.options` — otherwise `updateSession` would rebuild
        // the predicate from the pre-toggle value.
        filters.$options
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.didUpdateSearchCriteria()
            }
            .store(in: &cancellables)

        environment.$mode.sink { [weak self] in
            self?.configure(mode: $0)
        }.store(in: &cancellables)
    }

    private func configure(mode: ConsoleMode) {
        self.suggestionsService = ConsoleNetworkSearchSuggestionsService(mode: mode)
        self.suggestionsViewModel = suggestionsService.makeSuggestions(for: makeContextForSuggestions())
        if configuredMode != mode {
            configuredMode = mode
            if isDeepSearch {
                self.scopes = Set(allScopes)
            } else {
                let loaded = ConsoleSearchScope.loadPersistedScopes(for: mode)
                self.scopes = loaded
                self.savedDefaultScopes = loaded
            }
        }
        DispatchQueue.main.async {
            self.refreshNow()
        }
    }

    func resetScopesToDefault() {
        scopes = Set(defaultScopes)
        if let mode = configuredMode {
            ConsoleSearchScope.clearPersistedScopes(for: mode)
            savedDefaultScopes = scopes
        }
    }

    func saveCurrentScopesAsDefault() {
        guard !isDeepSearch, let mode = configuredMode else { return }
        ConsoleSearchScope.savePersistedScopes(scopes, for: mode)
        savedDefaultScopes = scopes
    }

    func setScopes(_ newScopes: Set<ConsoleSearchScope>) {
        scopes = newScopes
    }

    // MARK: Search

    private func didUpdateSearchCriteria() {
        newResultsCount = 0
        updateSession()
    }

    private func updateSession() {
        session?.cancel()
        session = nil

        let params = parameters
        guard !params.isEmpty else {
            isPerformingSearch = false
            results = []
            hasMore = false
            extendedResults = []
            hasMoreExtended = false
            isPerformingExtendedSearch = false
            return
        }

        let mode = environment.mode
        let primaryPredicate = ConsoleDataSource.makePredicate(mode: mode, options: filters.options)

        var extendedPredicate: NSPredicate?
        if !filters.options.sessions.isEmpty {
            var other = filters.options
            other.sessions = []
            extendedPredicate = ConsoleDataSource.makePredicate(mode: mode, options: other)
        }

        let session = ConsoleSearchSession(
            store: store,
            mode: mode,
            primaryPredicate: primaryPredicate,
            extendedPredicate: extendedPredicate,
            sortDescriptors: makeSortDescriptors(mode: mode),
            parameters: params
        )
        session.delegate = self
        if isDeepSearch { session.cutoff = 1000 }

        isPerformingSearch = true
        isAwaitingFirstResults = true
        hasMore = false
        extendedResults = []
        hasMoreExtended = false
        isPerformingExtendedSearch = false

        self.session = session
        session.start()
    }

    private func makeSortDescriptors(mode: ConsoleMode) -> [NSSortDescriptor] {
        let options = environment.listOptions
        let sortKey: String
        switch mode {
        case .all, .logs: sortKey = options.messageSortBy.key
        case .network: sortKey = options.taskSortBy.key
        }
        return [NSSortDescriptor(key: sortKey, ascending: options.order == .ascending)]
    }

    // MARK: ConsoleSearchSessionDelegate

    func searchSession(_ session: ConsoleSearchSession, didEmit events: [ConsoleSearchSession.Event]) {
        guard session === self.session else { return }
        for event in events {
            apply(event, from: session)
        }
    }

    private func apply(_ event: ConsoleSearchSession.Event, from session: ConsoleSearchSession) {
        switch event {
        case .results(let results):
            let resolved = results.map(makeResultViewModel)
            if isAwaitingFirstResults {
                isAwaitingFirstResults = false
                self.results = resolved
            } else {
                self.results += resolved
            }
        case .finished(let hasMore):
            isPerformingSearch = false
            if isAwaitingFirstResults {
                // Finished without delivering anything: clear leftover
                // results from the previous search.
                isAwaitingFirstResults = false
                self.results = []
            }
            self.hasMore = hasMore
            if !hasMore, !isDeepSearch {
                isPerformingExtendedSearch = true
                session.startExtendedSearch()
            }
        case .extendedResults(let results):
            self.extendedResults += results.map(makeResultViewModel)
        case .extendedFinished(let hasMore):
            isPerformingExtendedSearch = false
            hasMoreExtended = hasMore
        case .newMatches(let count):
            withAnimation {
                newResultsCount += count
            }
        case .removedMatches(let ids):
            if !ids.isEmpty {
                results.removeAll { ids.contains($0.entity.objectID) }
                extendedResults.removeAll { ids.contains($0.entity.objectID) }
            }
        }
    }

    private func makeResultViewModel(_ result: ConsoleSearchSession.Result) -> ConsoleSearchResultViewModel {
        ConsoleSearchResultViewModel(
            entity: store.viewContext.object(with: result.objectID),
            occurrences: result.occurrences
        )
    }

    // MARK: Actions

    func refreshNow() {
        if newResultsCount > 0 {
            withAnimation {
                newResultsCount = 0
            }
        }
        updateSession()
    }

    func perform(_ suggestion: ConsoleSearchSuggestion) {
        switch suggestion.action {
        case .applyTerm(let term):
            searchBar.text = term.text
            options = term.options
            recents.saveSearch(term)
        case .applyFilter(let filter):
            applyFilter(filter)
        }
        updateSearchTokens()
    }

    private func applyFilter(_ filter: ConsoleSearchFilterSuggestion) {
        applyToken(filter.token, filter: filter.makeCustomFilter())
    }

    func onSubmitSearch() {
        let searchTerm = searchBar.text.trimmingCharacters(in: .whitespaces)
        if !searchTerm.isEmpty {
            recents.saveSearch(.init(text: searchTerm, options: options))
        }
    }

    func buttonShowNewlyAddedSearchResultsTapped() {
        refreshNow()
    }

    func searchInOtherSessions() {
        filters.sessions = []
    }

    func buttonClearRecentSearchesTapped() {
        recents.clearRecentSearches()
        updateSearchTokens()
    }

    var recentSearches: [ConsoleSearchTerm] {
        recents.searches
    }

    func removeRecentSearch(_ term: ConsoleSearchTerm) {
        recents.removeSearch(term)
        updateSearchTokens()
    }

    func didScroll(to result: ConsoleSearchResultViewModel, isExtended: Bool = false) {
        if isExtended {
            guard extendedResults.count > 3 && extendedResults[extendedResults.endIndex - 2].entity.objectID == result.entity.objectID else {
                return
            }
            guard !isPerformingExtendedSearch && hasMoreExtended else {
                return
            }
            isPerformingExtendedSearch = true
            session?.loadMoreExtended()
        } else {
            guard results.count > 3 && results[results.endIndex - 2].entity.objectID == result.entity.objectID else {
                return
            }
            guard !isPerformingSearch && hasMore else {
                return
            }
            isPerformingSearch = true
            session?.loadMore()
        }
    }

    // MARK: Tab Completion

    private func handleTab(in text: String) {
        guard text.contains("\t") else { return }
        DispatchQueue.main.async { // Fixes text not clearing
            if let first = self.suggestionsViewModel?.filters.first {
                self.perform(first)
            }
        }
    }

    // MARK: Suggested Tokens

    private func updateSearchTokens() {
        self.suggestionsViewModel = suggestionsService.makeSuggestions(for: makeContextForSuggestions())
    }

    private func makeContextForSuggestions() -> ConsoleSearchSuggestionsContext {
        ConsoleSearchSuggestionsContext(
            searchText: searchBar.text.trimmingCharacters(in: .whitespaces),
            index: index,
            parameters: parameters
        )
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
extension ConsoleSearchViewModel: ConsoleSearchOptionsHost {}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleSearchResultViewModel: Identifiable {
    package var id: ConsoleSearchResultKey { ConsoleSearchResultKey(id: entity.objectID) }
    package let entity: NSManagedObject
    package let occurrences: [ConsoleSearchOccurrence]

    package init(entity: NSManagedObject, occurrences: [ConsoleSearchOccurrence]) {
        self.entity = entity
        self.occurrences = occurrences
    }
}

package struct ConsoleSearchResultKey: Hashable {
    package let id: NSManagedObjectID
}

package struct ConsoleSearchParameters {
    package var scopes: [ConsoleSearchScope] = []
    package var terms: [ConsoleSearchTerm] = []

    package var isEmpty: Bool {
        terms.isEmpty
    }

    package init(scopes: [ConsoleSearchScope] = [], terms: [ConsoleSearchTerm] = []) {
        self.scopes = scopes
        self.terms = terms
    }
}

#endif

package enum ConsoleUpdateEvent {
    /// Full refresh of data.
    case refresh
    /// Incremental update.
    case update(CollectionDifference<NSManagedObjectID>?)
}
