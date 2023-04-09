// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleViewModel: ObservableObject {
    let title: String
    let store: LoggerStore
#if PULSE_STANDALONE_APP
    var client: RemoteLoggerClient?
#endif
    let context: ConsoleContext

    let listViewModel: ConsoleListViewModel

#if os(iOS) || os(macOS)
    let insightsViewModel: InsightsViewModel
    @available(iOS 15, *)
    var searchViewModel: ConsoleSearchViewModel {
        _searchViewModel as! ConsoleSearchViewModel
    }
    private var _searchViewModel: AnyObject?

    let searchBarViewModel: ConsoleSearchBarViewModel
#endif

#if os(macOS)
    let tableViewModel: ConsoleTableViewModel
    let textViewModel: ConsoleTextViewModel
#endif

    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    let index: LoggerStoreIndex

    let logCountObserver: ManagedObjectsCountObserver
    let taskCountObserver: ManagedObjectsCountObserver

    let router = ConsoleRouter()

#if !os(macOS)
    // On macOS, these views are independent
    var isViewVisible: Bool = false {
        didSet { listViewModel.isViewVisible = isViewVisible }
    }

    var isSearching = false {
        didSet {
#if os(iOS)
            if #available(iOS 15, *) {
                searchViewModel.isViewVisible = isSearching
            }
#endif
        }
    }
#endif

    let initialMode: ConsoleMode

    var mode: ConsoleMode {
        didSet { prepare(for: mode) }
    }

    var bindingForNetworkMode: Binding<Bool> {
        Binding(get: {
            self.mode == .network
        }, set: {
            self.mode = $0 ? .network : .all
        })
    }

    var onDismiss: (() -> Void)?

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore,
         context: ConsoleContext = .init(),
         mode: ConsoleMode = .all
    ) {
        self.store = store
        self.title = context.title ?? {
            switch mode {
            case .all: return "Console"
            case .logs: return "Logs"
            case .network: return "Network"
            }
        }()
        self.context = context
        self.initialMode = mode
        self.mode = mode

        func makeDefaultSearchCriteria() -> ConsoleSearchCriteria {
            var criteria = ConsoleSearchCriteria()
            if store.isArchive {
                criteria.shared.dates.startDate = nil
            }
            if context.focus != nil {
                criteria.shared.dates.startDate = nil
            }
            return criteria
        }

        self.index = LoggerStoreIndex(store: store)
        self.searchCriteriaViewModel = ConsoleSearchCriteriaViewModel(criteria: makeDefaultSearchCriteria(), index: index)
        self.searchCriteriaViewModel.focus = context.focus
        self.listViewModel = ConsoleListViewModel(store: store, criteria: searchCriteriaViewModel)
#if os(iOS) || os(macOS)
        self.insightsViewModel = InsightsViewModel(store: store)
        self.searchBarViewModel = ConsoleSearchBarViewModel()
        if #available(iOS 15, *) {
            self._searchViewModel = ConsoleSearchViewModel(list: listViewModel, index: index, searchBar: searchBarViewModel)
        }
#endif

#if os(macOS)
        self.tableViewModel = ConsoleTableViewModel(store: store, criteria: searchCriteriaViewModel)
        self.textViewModel = ConsoleTextViewModel(store: store, criteria: searchCriteriaViewModel, router: router)
#endif

        self.logCountObserver = ManagedObjectsCountObserver(
            entity: LoggerMessageEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)
        )

        self.taskCountObserver = ManagedObjectsCountObserver(
            entity: NetworkTaskEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: false)
        )

#if os(iOS) || os(macOS)
        self.insightsViewModel.consoleViewModel = self
#endif

        bind()

        if mode != .all {
            prepare(for: mode)
        }
    }

#if PULSE_STANDALONE_APP
    convenience init(client: RemoteLoggerClient) throws {
        let store = try client.open()
        self.init(store: store)
        self.client = client
    }
#endif

#if os(macOS)
    func focus(on entities: [NSManagedObject]) {
        searchCriteriaViewModel.focus = NSPredicate(format: "self IN %@", entities)
        listViewModel.options.messageGroupBy = .noGrouping
        listViewModel.options.taskGroupBy = .noGrouping
    }
#endif

    private func bind() {
        let criteria = searchCriteriaViewModel

        criteria.bind(listViewModel.$entities)

#warning("refactor (combine these parameters in a single properly")
        Publishers.CombineLatest4(criteria.$criteria, criteria.$focus, criteria.$isOnlyErrors, criteria.$sessions).sink { [weak self] in
            self?.refreshCountObservers(criteria: $0, focus: $1, isOnlyError: $2, sessions: $3)
        }.store(in: &cancellables)
    }

    private func refreshCountObservers(criteria: ConsoleSearchCriteria, focus: NSPredicate?, isOnlyError: Bool, sessions: Set<LoggerSessionEntity>) {
        func makePredicate(for mode: ConsoleMode) -> NSPredicate? {
            ConsoleDataSource.makePredicate(mode: mode, criteria: criteria, focus: focus, isOnlyErrors: isOnlyError, sessions: sessions)
        }
        logCountObserver.setPredicate(makePredicate(for: .logs))
        taskCountObserver.setPredicate(makePredicate(for: .network))
    }

    private func prepare(for mode: ConsoleMode) {
        searchCriteriaViewModel.mode = mode
        listViewModel.mode = mode
#if os(macOS)
        tableViewModel.mode = mode
        textViewModel.mode = mode
#endif
    }

    func prepareForSharing(as output: ShareOutput, _ completion: @escaping (ShareItems?) -> Void) {
        ShareService.share(listViewModel.entities, store: store, as: output, completion)
    }
}

struct ConsoleContext {
    var title: String?
    var focus: NSPredicate?
}

public enum ConsoleMode: String {
    /// Displays both messages and network tasks with the ability
    /// to switch between the two modes.
    case all
    /// Displays only regular messages.
    case logs
    /// Displays only network tasks.
    case network
}
