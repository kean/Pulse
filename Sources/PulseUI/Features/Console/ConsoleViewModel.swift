// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

#warning("TODO: add mode for messages only (or add context menu to hide network?)")
#warning("TODO: switch to network filters and share date fiters")

final class ConsoleViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
#if os(iOS) || os(macOS)
    let table: ConsoleTableViewModel
#endif
    @Published private(set) var entities: [NSManagedObject] = []
    @Published var mode: Mode

    enum Mode {
        case all
        case network
    }

    let details: ConsoleDetailsRouterViewModel

    // Search criteria
    let searchCriteria: ConsoleSearchCriteriaViewModel
    @Published var isOnlyErrors: Bool = false
    @Published var isOnlyNetwork: Bool = false
    @Published var filterTerm: String = ""

    var onDismiss: (() -> Void)?

    private(set) var store: LoggerStore
    private var controller: NSFetchedResultsController<NSManagedObject>?
    private var isActive = false
    private var latestSessionId: UUID?
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: Mode = .all) {
        self.store = store
        self.mode = mode

        self.details = ConsoleDetailsRouterViewModel()
        self.searchCriteria = ConsoleSearchCriteriaViewModel(store: store)
#if os(iOS) || os(macOS)
        self.table = ConsoleTableViewModel(searchCriteriaViewModel: searchCriteria)
#endif

        super.init()

        $filterTerm.throttle(for: 0.25, scheduler: RunLoop.main, latest: true).dropFirst().sink { [weak self] filterTerm in
            self?.refresh(filterTerm: filterTerm)
        }.store(in: &cancellables)

        searchCriteria.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
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
        // Get sessionId
        if latestSessionId == nil {
            latestSessionId = (entities.first as? LoggerMessageEntity)?.session ?? (entities.first as? NetworkTaskEntity)?.session
        }
        let sessionId = store === LoggerStore.shared ? LoggerStore.Session.current.id : latestSessionId

        // Search messages
        guard let controller = controller else {
            return assertionFailure()
        }
        switch mode {
        case .all:
            ConsoleSearchCriteria.update(request: controller.fetchRequest, filterTerm: filterTerm, criteria: searchCriteria.criteria, filters: searchCriteria.filters, sessionId: sessionId, isOnlyErrors: isOnlyErrors, isOnlyNetwork: isOnlyNetwork)
        case .network:
            #warning("TODO: apply search criteria")
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
