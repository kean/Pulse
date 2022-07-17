// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

final class NetworkViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
#if os(iOS)
    let table: ConsoleTableViewModel

    @Published private(set) var entities: [LoggerNetworkRequestEntity] = [] {
        didSet { table.entities = entities }
    }
#else
    @Published private(set) var entities: [LoggerNetworkRequestEntity] = []
#endif

    // Search criteria
    let searchCriteria: NetworkSearchCriteriaViewModel
    @Published var isOnlyErrors: Bool = false
    @Published var filterTerm: String = ""

    var onDismiss: (() -> Void)?

    private(set) var store: LoggerStore
    private let controller: NSFetchedResultsController<LoggerNetworkRequestEntity>
    private var latestSessionId: String?
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore) {
        self.store = store

        let request = NSFetchRequest<LoggerNetworkRequestEntity>(entityName: "\(LoggerNetworkRequestEntity.self)")
        request.fetchBatchSize = 250
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerNetworkRequestEntity.createdAt, ascending: false)]

        self.controller = NSFetchedResultsController<LoggerNetworkRequestEntity>(fetchRequest: request, managedObjectContext: store.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        self.searchCriteria = NetworkSearchCriteriaViewModel(isDefaultStore: store === LoggerStore.default)
#if os(iOS)
        self.table = ConsoleTableViewModel(store: store, searchCriteriaViewModel: nil)
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

        store.backgroundContext.perform {
            self.getAllDomains()
        }
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
        let sessionId = store === LoggerStore.default ? LoggerSession.current.id.uuidString : latestSessionId

        // Search messages
        NetworkSearchCriteria.update(request: controller.fetchRequest, filterTerm: filterTerm, criteria: searchCriteria.criteria, filters: searchCriteria.filters, isOnlyErrors: isOnlyErrors, sessionId: sessionId)
        try? controller.performFetch()

        self.didRefreshEntities()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    private var isUpdateOnly = false

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        if type != .update {
            isUpdateOnly = false
        }
        switch type {
        case .insert:
            if let entity = anObject as? LoggerNetworkRequestEntity {
                searchCriteria.didInsertEntity(entity)
            }
        default:
            break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if !isUpdateOnly {
            self.didRefreshEntities()
        }
        isUpdateOnly = true
    }

    private func didRefreshEntities() {
        // Apply filters that couldn't be done programmatically
        if let filters = searchCriteria.programmaticFilters {
            let objects = controller.fetchedObjects ?? []
            self.entities = objects.filter { evaluateProgrammaticFilters(filters, entity: $0, store: store) }
        } else {
            self.entities = controller.fetchedObjects ?? []
        }
    }

    // MARK: - Misc

    private func getAllDomains() {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "\(LoggerNetworkRequestEntity.self)")

        // Required! Unless you set the resultType to NSDictionaryResultType, distinct can't work.
        // All objects in the backing store are implicitly distinct, but two dictionaries can be duplicates.
        // Since you only want distinct names, only ask for the 'name' property.
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.propertiesToFetch = ["host"]
        fetchRequest.returnsDistinctResults = true

        // Now it should yield an NSArray of distinct values in dictionaries.
        let map = (try? store.backgroundContext.fetch(fetchRequest)) ?? []
        let values = (map as? [[String: String]])?.compactMap { $0["host"] }
        let set = Set(values ?? [])

        DispatchQueue.main.async {
            self.searchCriteria.setInitialDomains(set)
        }
    }
}
