// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

#if os(iOS)

final class PinsViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    let table: ConsoleTableViewModel
    let details: ConsoleDetailsRouterViewModel

    @Published private(set) var messages: [LoggerMessageEntity] = [] {
        didSet { table.entities = messages }
    }

    var onDismiss: (() -> Void)?

    private let store: LoggerStore
    private var isActive = false
    private let controller: NSFetchedResultsController<LoggerMessageEntity>
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore) {
        self.store = store
        self.details = ConsoleDetailsRouterViewModel()

        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
        request.fetchBatchSize = 100
        request.relationshipKeyPathsForPrefetching = ["request"]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)]
        request.predicate = NSPredicate(format: "isPinned == YES")

        self.controller = NSFetchedResultsController<LoggerMessageEntity>(fetchRequest: request, managedObjectContext: store.viewContext, sectionNameKeyPath: nil, cacheName: nil)

        self.table = ConsoleTableViewModel(searchCriteriaViewModel: nil)

        super.init()

        controller.delegate = self

        refreshNow()
    }

    // MARK: Appearance

    func onAppear() {
        isActive = true
        refreshNow()
    }

    func onDisappear() {
        isActive = false
    }

    private func refreshNow() {
        try? controller.performFetch()
        self.messages = controller.fetchedObjects ?? []
    }

    func removeAllPins() {
        store.pins.removeAllPins()
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        if isActive {
            self.messages = self.controller.fetchedObjects ?? []
        }
    }
}

#endif
