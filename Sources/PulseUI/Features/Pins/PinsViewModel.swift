// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

#if os(iOS) || os(tvOS)

final class PinsViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
#if os(iOS)
    let table: ConsoleTableViewModel

    @Published private(set) var messages: [LoggerMessageEntity] = [] {
        didSet { table.entities = messages }
    }
#else
    @Published private(set) var messages: [LoggerMessageEntity] = []
#endif

    var onDismiss: (() -> Void)?

    private(set) var store: LoggerStore
    private let controller: NSFetchedResultsController<LoggerMessageEntity>
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore) {
        self.store = store

        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
        request.fetchBatchSize = 250
        request.relationshipKeyPathsForPrefetching = ["request"]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)]
        request.predicate = NSPredicate(format: "isPinned == YES")

        self.controller = NSFetchedResultsController<LoggerMessageEntity>(fetchRequest: request, managedObjectContext: store.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
#if os(iOS)
        self.table = ConsoleTableViewModel(store: store, searchCriteriaViewModel: nil)
#endif

        super.init()

        controller.delegate = self

        refreshNow()
    }

    private func refreshNow() {
        try? controller.performFetch()
        self.messages = controller.fetchedObjects ?? []
    }

    func removeAllPins() {
        store.removeAllPins()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.messages = self.controller.fetchedObjects ?? []
    }
}

#endif
