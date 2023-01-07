// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

#if os(macOS) || os(tvOS)

final class NetworkViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
#if os(macOS)
    let table: ConsoleTableViewModel
#endif
    @Published private(set) var entities: [NetworkTaskEntity] = []

    let details: ConsoleDetailsRouterViewModel

    // Search criteria
    let searchCriteria: ConsoleNetworkSearchCriteriaViewModel
    @Published var isOnlyErrors: Bool = false
    @Published var filterTerm: String = ""

    var onDismiss: (() -> Void)?

    let store: LoggerStore
    private let controller: NSFetchedResultsController<NetworkTaskEntity>
    private var isActive = false
    private var latestSessionId: UUID?
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore) {
        self.store = store
        self.details = ConsoleDetailsRouterViewModel()

        let request = NSFetchRequest<NetworkTaskEntity>(entityName: "\(NetworkTaskEntity.self)")
        request.fetchBatchSize = 100
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: false)]

        self.controller = NSFetchedResultsController<NetworkTaskEntity>(fetchRequest: request, managedObjectContext: store.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        self.searchCriteria = ConsoleNetworkSearchCriteriaViewModel(store: store)
#if os(macOS)
        self.table = ConsoleTableViewModel(searchCriteriaViewModel: nil)
#endif

        super.init()

        controller.delegate = self

        $filterTerm.dropFirst().sink { [weak self] filterTerm in
            self?.refresh(filterTerm: filterTerm)
        }.store(in: &cancellables)

        searchCriteria.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
            self?.refreshNow()
        }.store(in: &cancellables)

        $isOnlyErrors.receive(on: DispatchQueue.main).dropFirst().sink { [weak self] _ in
            self?.refreshNow()
        }.store(in: &cancellables)

        refreshNow()
    }

    func getObservableProperties() -> CurrentValueSubject<[NSManagedObject], Never> {
        let subject = CurrentValueSubject<[NSManagedObject], Never>(entities)
        $entities.sink { subject.send($0) }.store(in: &cancellables)
        return subject
    }

    // MARK: Appearance

    func onAppear() {
        isActive = true
        didRefreshEntities()
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
            latestSessionId = entities.first?.session
        }
        let sessionId = store === LoggerStore.shared ? LoggerStore.Session.current.id : latestSessionId

        // Search messages
//        NetworkSearchCriteria.update(request: controller.fetchRequest, filterTerm: filterTerm, criteria: searchCriteria.criteria, filters: searchCriteria.filters, isOnlyErrors: isOnlyErrors, sessionId: sessionId)
        try? controller.performFetch()

        self.didRefreshEntities()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        guard isActive else { return }

#if os(macOS)
        self.table.diff = diff
#endif
        withAnimation {
            self.didRefreshEntities()
        }
    }

    private func didRefreshEntities() {
        // Apply filters that couldn't be done programmatically
        if let filters = searchCriteria.programmaticFilters {
            let objects = controller.fetchedObjects ?? []
            self.entities = objects.filter { evaluateProgrammaticFilters(filters, entity: $0, store: store) }
        } else {
            self.entities = controller.fetchedObjects ?? []
        }
        #if os(macOS)
        self.table.entities = self.entities
        #endif
    }
}

#endif
