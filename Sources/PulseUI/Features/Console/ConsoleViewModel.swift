// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

#warning("container for ConsoleVieWModl that doesn't refresh itself")
#warning("rework public API")

final class ConsoleViewModel: ObservableObject {
    let title: String
    let isNetworkOnly: Bool
    let store: LoggerStore

    let list: ConsoleListViewModel

#if os(iOS)
    let insightsViewModel: InsightsViewModel
    @available(iOS 15, tvOS 15, *)
    var searchViewModel: ConsoleSearchViewModel {
        _searchViewModel as! ConsoleSearchViewModel
    }
    private var _searchViewModel: AnyObject?
#endif

    let searchBarViewModel: ConsoleSearchBarViewModel
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    #warning("reimplement this")
    var toolbarTitle: String {
        let suffix = mode == .network ? "Requests" : "Messages"
        return "\(0) \(suffix)"
    }

    var isViewVisible: Bool = false {
        didSet { refreshListsVisibility() }
    }

    var isSearching = false {
        didSet { refreshListsVisibility() }
    }

    // Filters
    @Published var mode: ConsoleMode
    @Published var isOnlyErrors = false
    @Published var filterTerm: String = ""
    @Published var isShowingFilters = false

    var onDismiss: (() -> Void)?

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: ConsoleMode = .messages) {
        self.title = mode == .network ? "Network" : "Console"
        self.store = store
        self.mode = mode
        self.isNetworkOnly = mode == .network

        self.searchCriteriaViewModel = ConsoleSearchCriteriaViewModel(store: store)
        self.searchBarViewModel = ConsoleSearchBarViewModel()
        self.list = ConsoleListViewModel(store: store, mode: mode, criteria: searchCriteriaViewModel)

#if os(iOS)
        self.insightsViewModel = InsightsViewModel(store: store)
        if #available(iOS 15, *) {
            self._searchViewModel = ConsoleSearchViewModel(entities: list.entitiesSubject, store: store, searchBar: searchBarViewModel)
        }
#endif

        searchCriteriaViewModel.bind(list.$entities)

        $filterTerm
            .dropFirst()
            .throttle(for: 0.25, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] filterTerm in
                self?.refresh(filterTerm: filterTerm)
            }.store(in: &cancellables)

        searchCriteriaViewModel.$criteria
            .dropFirst()
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.refreshList() }
            .store(in: &cancellables)

        $isOnlyErrors.receive(on: DispatchQueue.main).dropFirst().sink { [weak self] _ in
            self?.refreshList()
        }.store(in: &cancellables)

        list.refreshController()
    }

    // MARK: Mode

    func toggleMode() {
        switch mode {
        case .messages: mode = .network
        case .network: mode = .messages
        }
        list.refreshController()
    }

    // MARK: Refresh

    private func refreshListsVisibility() {
        list.isViewVisible = !isSearching && isViewVisible
        if #available(iOS 15, tvOS 15, *) {
            searchViewModel.isViewVisible = isSearching && isViewVisible
        }
    }

    private func refreshList() {
        // important: order
        refresh(filterTerm: filterTerm)

#warning("reomplement")
#if os(iOS)
        if #available(iOS 15, *) {
            searchViewModel.refreshNow()
        }
#endif
    }

    #warning("remove")
    private func refresh(filterTerm: String) {
        list.refresh()
    }

    // MARK: - Sharing

    func prepareForSharing(as output: ShareOutput, _ completion: @escaping (ShareItems?) -> Void) {
        ShareService.share(list.entities, store: store, as: output, completion)
    }
}

enum ConsoleMode {
    case messages, network
}
