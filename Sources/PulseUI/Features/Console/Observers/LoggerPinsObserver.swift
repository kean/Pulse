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

    private(set) var allPins: [LoggerMessageEntity] = [] {
        didSet { updateFilteredPins() }
    }

    var mode: ConsoleMode = .all {
        didSet { updateFilteredPins() }
    }

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
        allPins = controller.fetchedObjects ?? []
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        allPins = self.controller.fetchedObjects ?? []
    }

    private func updateFilteredPins() {
        pins = allPins.filter {
            switch mode {
            case .all: return true
            case .logs: return $0.task == nil
            case .tasks: return $0.task != nil
            }
        }
    }
}
