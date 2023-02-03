// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

final class LoggerPinsObserver: NSObject, NSFetchedResultsControllerDelegate {
    @Published private(set) var pins: [LoggerMessageEntity] = []

    private let controller: NSFetchedResultsController<LoggerMessageEntity>

    init(store: LoggerStore) {
        self.controller = NSFetchedResultsController(
            fetchRequest: {
                let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)]
                request.predicate = NSPredicate(format: "isPinned == YES")
                return request
            }(),
            managedObjectContext: store.viewContext,
            sectionNameKeyPath: nil,
            cacheName: "com.github.pulse.pins-cache"
        )
        super.init()

        controller.delegate = self
        try? controller.performFetch()
        pins = controller.fetchedObjects ?? []
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        pins = self.controller.fetchedObjects ?? []
    }
}
