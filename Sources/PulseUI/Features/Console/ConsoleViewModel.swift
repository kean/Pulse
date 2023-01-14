// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    let title: String
    let isNetworkOnly: Bool
    let store: LoggerStore

#if os(iOS) || os(macOS)
    let table: ConsoleTableViewModel
    let details: ConsoleDetailsRouterViewModel
#endif

    @Published private(set) var entities: [NSManagedObject] = []
    let entitiesSubject = CurrentValueSubject<[NSManagedObject], Never>([])

#if os(iOS)
    let insightsViewModel: InsightsViewModel
#endif

    let searchViewModel: ConsoleSearchViewModel

    @Published var mode: Mode
    @Published var isOnlyErrors = false
    @Published var filterTerm: String = ""

    var onDismiss: (() -> Void)?

    private var controller: NSFetchedResultsController<NSManagedObject>?
    private var isActive = false
    private var cancellables: [AnyCancellable] = []

    enum Mode {
        case messages, network
    }

    init(store: LoggerStore, mode: Mode = .messages) {
        self.title = mode == .network ? "Network" : "Console"
        self.store = store
        self.mode = mode
        self.isNetworkOnly = mode == .network

        self.searchViewModel = ConsoleSearchViewModel(store: store, entities: entitiesSubject)

#if os(iOS) || os(macOS)
        self.details = ConsoleDetailsRouterViewModel()
        self.table = ConsoleTableViewModel(searchViewModel: searchViewModel)
#endif

#if os(iOS)
        self.insightsViewModel = InsightsViewModel(store: store)
#endif

        super.init()

        $entities.sink { [entitiesSubject] in
            entitiesSubject.send($0)
        }.store(in: &cancellables)

        $filterTerm
            .dropFirst()
            .throttle(for: 0.25, scheduler: RunLoop.main, latest: true)
            .sink { [weak self] filterTerm in
                self?.refresh(filterTerm: filterTerm)
            }.store(in: &cancellables)

        searchViewModel.$criteria
            .dropFirst()
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.refreshNow() }
            .store(in: &cancellables)

        $isOnlyErrors.receive(on: DispatchQueue.main).dropFirst().sink { [weak self] _ in
            self?.refreshNow()
        }.store(in: &cancellables)

        prepare(for: mode)
    }

    // MARK: Mode

    func toggleMode() {
        switch mode {
        case .messages: mode = .network
        case .network: mode = .messages
        }
        prepare(for: mode)
    }

    private func prepare(for mode: Mode) {
        searchViewModel.mode = mode

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
        case .messages:
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeMessagePredicates(criteria: searchViewModel.criteria, isOnlyErrors: isOnlyErrors, filterTerm: filterTerm)
        case .network:
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeNetworkPredicates(criteria: searchViewModel.criteria, isOnlyErrors: isOnlyErrors, filterTerm: filterTerm)
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

    // MARK: - Sharing

    func prepareForSharing(as output: ShareOutput, _ completion: @escaping (ShareItems?) -> Void) {
        ShareService.share(entities, store: store, as: output, completion)
    }
}

private func makeFetchRequest(for mode: ConsoleViewModel.Mode) -> NSFetchRequest<NSManagedObject> {
    let request: NSFetchRequest<NSManagedObject>
    switch mode {
    case .messages:
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
