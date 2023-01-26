// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleViewModel: ObservableObject {
    let title: String
    let isNetwork: Bool
    let store: LoggerStore
    let source: ConsoleSource

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

    var mode: ConsoleMode {
        didSet { prepare(for: mode) }
    }

    var bindingForNetworkMode: Binding<Bool> {
        Binding(get: {
            self.mode == .tasks
        }, set: {
            self.mode = $0 ? .tasks : .all
        })
    }

    var onDismiss: (() -> Void)?

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, source: ConsoleSource = .store, mode: ConsoleMode = .all, isOnlyNetwork: Bool = false) {
        switch source {
        case .store:
            self.title = isOnlyNetwork ? "Network" : "Console"
        case .entities(let title, _):
            self.title = title
        }

        self.store = store
        self.source = source
        self.mode = mode
        self.isNetwork = isOnlyNetwork

        self.searchCriteriaViewModel = ConsoleSearchCriteriaViewModel(store: store, source: source)

        self.searchBarViewModel = ConsoleSearchBarViewModel()
        self.list = ConsoleListViewModel(store: store, source: source, criteria: searchCriteriaViewModel)

#if os(iOS)
        self.insightsViewModel = InsightsViewModel(store: store)
        if #available(iOS 15, *) {
            self._searchViewModel = ConsoleSearchViewModel(entities: list.entitiesSubject, store: store, searchBar: searchBarViewModel)
        }
#endif

        prepare(for: mode)
        searchCriteriaViewModel.bind(list.$entities)
        searchCriteriaViewModel.bind(accumulatedLabels: list.$accumulatedLabels)
        searchCriteriaViewModel.bind(accumulatedHosts: list.$accumulatedHosts)
    }

    private func prepare(for mode: ConsoleMode) {
        list.update(mode: mode)
        searchCriteriaViewModel.mode = mode
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

enum ConsoleSource {
    case store
    case entities(title: String, entities: [NSManagedObject])
}
