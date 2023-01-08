// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    let title: String
#if os(iOS) || os(macOS)
    let table: ConsoleTableViewModel
#endif
    @Published private(set) var entities: [NSManagedObject] = []
    @Published var mode: Mode
    let isNetworkOnly: Bool

    enum Mode {
        case all
        case network
    }

    let details: ConsoleDetailsRouterViewModel
#if os(iOS)
    let insightsViewModel: InsightsViewModel
#endif

    // Search criteria
    let sharedSearchCriteriaViewModel: ConsoleSharedSearchCriteriaViewModel
    let searchCriteriaViewModel: ConsoleMessageSearchCriteriaViewModel
    let networkSearchCriteriaViewModel: ConsoleNetworkSearchCriteriaViewModel

    var isDefaultFilters: Bool {
        switch mode {
        case .all: return searchCriteriaViewModel.isDefaultSearchCriteria && sharedSearchCriteriaViewModel.isDefaultSearchCriteria
        case .network: return networkSearchCriteriaViewModel.isDefaultSearchCriteria && sharedSearchCriteriaViewModel.isDefaultSearchCriteria
        }
    }

    @Published var isOnlyErrors: Bool = false
    @Published var filterTerm: String = ""

    var onDismiss: (() -> Void)?

    private(set) var store: LoggerStore
    private var controller: NSFetchedResultsController<NSManagedObject>?
    private var isActive = false
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: Mode = .all) {
        self.title = mode == .network ? "Network" : "Console"
        self.store = store
        self.mode = mode
        self.isNetworkOnly = mode == .network

        self.details = ConsoleDetailsRouterViewModel()
#if os(iOS)
        self.insightsViewModel = InsightsViewModel(store: store)
#endif

        self.sharedSearchCriteriaViewModel = ConsoleSharedSearchCriteriaViewModel(store: store)
        self.searchCriteriaViewModel = ConsoleMessageSearchCriteriaViewModel(store: store)
        self.networkSearchCriteriaViewModel = ConsoleNetworkSearchCriteriaViewModel(store: store)

#if os(iOS) || os(macOS)
        self.table = ConsoleTableViewModel(searchCriteriaViewModel: searchCriteriaViewModel)
#endif

        super.init()

        $filterTerm.throttle(for: 0.25, scheduler: RunLoop.main, latest: true).dropFirst().sink { [weak self] filterTerm in
            self?.refresh(filterTerm: filterTerm)
        }.store(in: &cancellables)

        sharedSearchCriteriaViewModel.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
            self?.refreshNow()
        }.store(in: &cancellables)

        searchCriteriaViewModel.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
            self?.refreshNow()
        }.store(in: &cancellables)

        networkSearchCriteriaViewModel.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
            self?.refreshNow()
        }.store(in: &cancellables)

        $isOnlyErrors.receive(on: DispatchQueue.main).dropFirst().sink { [weak self] _ in
            self?.refreshNow()
        }.store(in: &cancellables)

        prepare(for: mode)
    }

    func getObservableProperties() -> CurrentValueSubject<[NSManagedObject], Never> {
        let subject = CurrentValueSubject<[NSManagedObject], Never>(entities)
        $entities.sink { subject.send($0) }.store(in: &cancellables)
        return subject
    }

    // MARK: Mode

    func toggleMode() {
        switch mode {
        case .all: mode = .network
        case .network: mode = .all
        }
        prepare(for: mode)
    }

    private func prepare(for mode: Mode) {
        let request = makeFetchRequest(for: mode)
        controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: store.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller?.delegate = self

        refreshNow()
    }

    // MARK: Appearance

    func onAppear() {
        isActive = true
        reloadMessages()
    }

    func onDisappear() {
        isActive = false
    }

    // MARK: Refresh

    private func refreshNow() {
        refresh(filterTerm: filterTerm)
    }

    private func refresh(filterTerm: String) {
        // Search messages
        guard let controller = controller else {
            return assertionFailure()
        }
        switch mode {
        case .all:
            let viewModel = searchCriteriaViewModel
            ConsoleMessageSearchCriteria.update(
                request: controller.fetchRequest,
                filterTerm: filterTerm,
                dates: sharedSearchCriteriaViewModel.dates,
                criteria: viewModel.criteria,
                filters: viewModel.filters,
                isOnlyErrors: isOnlyErrors
            )
        case .network:
            let viewModel = networkSearchCriteriaViewModel
#if !os(watchOS)
            NetworkSearchCriteria.update(
                request: controller.fetchRequest,
                filterTerm: filterTerm,
                dates: sharedSearchCriteriaViewModel.dates,
                criteria: viewModel.criteria,
                filters: viewModel.filters,
                isOnlyErrors: isOnlyErrors
            )
#endif
            break
        }
        try? controller.performFetch()

        reloadMessages()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        guard isActive else { return }

#if os(iOS) || os(macOS)
        self.table.diff = diff
#endif
        withAnimation {
            reloadMessages()
        }
    }

    private func reloadMessages() {
        entities = controller?.fetchedObjects ?? []
#if os(iOS) || os(macOS)
        table.entities = entities
#endif
    }
}

private func makeFetchRequest(for mode: ConsoleViewModel.Mode) -> NSFetchRequest<NSManagedObject> {
    let request: NSFetchRequest<NSManagedObject>
    switch mode {
    case .all:
        request = .init(entityName: "\(LoggerMessageEntity.self)")
        request.relationshipKeyPathsForPrefetching = ["request"]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)]
    case .network:
        request = .init(entityName: "\(NetworkTaskEntity.self)")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: false)]
    }
    request.fetchBatchSize = 100
    return request
}
