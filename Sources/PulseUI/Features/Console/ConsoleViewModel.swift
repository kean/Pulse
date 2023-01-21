// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleViewModel: ObservableObject {
    let title: String
    let isNetworkModeEnabled: Bool
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

    let router = ConsoleRouter()

    var isViewVisible: Bool = false {
        didSet { refreshListsVisibility() }
    }

    var isSearching = false {
        didSet { refreshListsVisibility() }
    }

    var onDismiss: (() -> Void)?

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, isOnlyNetwork: Bool = false) {
        self.title = isOnlyNetwork ? "Network" : "Console"
        self.store = store
        self.isNetworkModeEnabled = isOnlyNetwork

        self.searchCriteriaViewModel = ConsoleSearchCriteriaViewModel(store: store)
        self.searchBarViewModel = ConsoleSearchBarViewModel()
        self.list = ConsoleListViewModel(store: store, criteria: searchCriteriaViewModel)

#if os(iOS)
        self.insightsViewModel = InsightsViewModel(store: store)
        if #available(iOS 15, *) {
            self._searchViewModel = ConsoleSearchViewModel(entities: list.entitiesSubject, store: store, searchBar: searchBarViewModel)
        }

        list.didRefresh.sink { [weak self] in
            if #available(iOS 15, *) {
                self?.searchViewModel.refreshNow()
            }
        }.store(in: &cancellables)
#endif

        searchCriteriaViewModel.bind(list.$entities)
    }

    private func refreshListsVisibility() {
        list.isViewVisible = !isSearching && isViewVisible
#if os(iOS)
        if #available(iOS 15, *) {
            searchViewModel.isViewVisible = isSearching && isViewVisible
        }
#endif
    }

    func prepareForSharing(as output: ShareOutput, _ completion: @escaping (ShareItems?) -> Void) {
        ShareService.share(list.entities, store: store, as: output, completion)
    }
}
