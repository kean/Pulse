// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class NetworkViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    @Published private(set) var entities: AnyCollection<LoggerNetworkRequestEntity> = AnyCollection([])

    // Search criteria
    let searchCriteria: NetworkSearchCriteriaViewModel
    @Published var filterTerm: String = ""
    // TODO: implement quick filters
    // @Published private(set) var quickFilters: [QuickFilterViewModel] = []

    // TODO: get DI right, this is a quick workaround to fix @EnvironmentObject crashes
    var context: AppContext { .init(store: store) }

    private let store: LoggerStore
    private let controller: NSFetchedResultsController<LoggerNetworkRequestEntity>
    private var latestSessionId: String?
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore) {
        self.store = store

        let request = NSFetchRequest<LoggerNetworkRequestEntity>(entityName: "\(LoggerNetworkRequestEntity.self)")
        request.fetchBatchSize = 250
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerNetworkRequestEntity.createdAt, ascending: true)]

        self.controller = NSFetchedResultsController<LoggerNetworkRequestEntity>(fetchRequest: request, managedObjectContext: store.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        #warning("TODO: implement isDefaultStore")
        self.searchCriteria = NetworkSearchCriteriaViewModel() // (isDefaultStore: store === LoggerStore.default)

        super.init()

        controller.delegate = self

        $filterTerm.throttle(for: 0.33, scheduler: RunLoop.main, latest: true).dropFirst().sink { [weak self] filterTerm in
            self?.refresh(filterTerm: filterTerm)
        }.store(in: &cancellables)

        searchCriteria.dataNeedsReload.throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true).sink { [weak self] in
            self?.refreshNow()
        }.store(in: &cancellables)

        refreshNow()
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
        NetworkSearchCriteria.update(request: controller.fetchRequest, filterTerm: filterTerm, criteria: searchCriteria.criteria, filters: searchCriteria.filters, isOnlyErrors: false, sessionId: sessionId)
        try? controller.performFetch()

        self.didRefreshEntities()
    }

    // MARK: - NSFetchedResultsControllerDelegate

    // This never gets called on macOS
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.didRefreshEntities()
    }

    private func didRefreshEntities() {
        var entities: AnyCollection<LoggerNetworkRequestEntity>

        // Apply filters that couldn't be done programmatically
        if let filters = searchCriteria.programmaticFilters {
            let objects = controller.fetchedObjects ?? []
            entities = AnyCollection(objects.filter { evaluateProgrammaticFilters(filters, entity: $0, store: store) })
        } else {
            entities = AnyCollection(FetchedObjects(controller: controller))
        }

        self.entities = entities
    }
}
