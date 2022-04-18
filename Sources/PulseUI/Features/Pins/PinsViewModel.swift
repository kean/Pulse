// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

#if os(iOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, *)
final class PinsViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    @Published private(set) var messages: [LoggerMessageEntity] = []

    var onDismiss: (() -> Void)?

    // TODO: get DI right, this is a quick workaround to fix @EnvironmentObject crashes
    var context: AppContext { .init(store: store) }

    private let store: LoggerStore
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
