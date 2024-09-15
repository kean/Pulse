// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

package final class ManagedObjectsObserver<T: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate {
    @Published private(set) package var objects: [T] = []

    private let controller: NSFetchedResultsController<T>

    package init(request: NSFetchRequest<T>,
         context: NSManagedObjectContext,
         cacheName: String? = nil) {
        self.controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: cacheName)
        super.init()

        try? controller.performFetch()
        objects = controller.fetchedObjects ?? []

        controller.delegate = self
    }

    package func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        objects = self.controller.fetchedObjects ?? []
    }
}

extension ManagedObjectsObserver where T == LoggerSessionEntity {
    package static func sessions(for context: NSManagedObjectContext) -> ManagedObjectsObserver {
        let request = NSFetchRequest<LoggerSessionEntity>(entityName: "\(LoggerSessionEntity.self)")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)]

        return ManagedObjectsObserver(request: request, context: context, cacheName: "com.github.pulse.sessions-cache")
    }
}
