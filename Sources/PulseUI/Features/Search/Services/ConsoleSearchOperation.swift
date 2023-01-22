// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
protocol ConsoleSearchOperationDelegate: AnyObject {
    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel])
    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool)
}

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchOperation {
    private let parameters: ConsoleSearchParameters
    private var entities: [NSManagedObject]
    private var objectIDs: [NSManagedObjectID]
    private var index = 0
    private var cutoff = 10
    private let service: ConsoleSearchService
    private let context: NSManagedObjectContext
    private let lock: os_unfair_lock_t
    private var _isCancelled = false

    weak var delegate: ConsoleSearchOperationDelegate?

    init(entities: [NSManagedObject],
         parameters: ConsoleSearchParameters,
         service: ConsoleSearchService,
         context: NSManagedObjectContext) {
        self.entities = entities
        self.objectIDs = entities.map(\.objectID)
        self.parameters = parameters
        self.service = service
        self.context = context

        self.lock = .allocate(capacity: 1)
        self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func resume() {
        context.perform { self._start() }
    }

    private func _start() {
        var found = 0
        var hasMore = false
        while index < objectIDs.count, !isCancelled, !hasMore {
            let currentMatchIndex = index
            if let entity = try? self.context.existingObject(with: objectIDs[index]),
               let occurrences = self.service.search(entity, parameters: parameters) {
                found += 1
                if found > cutoff {
                    hasMore = true
                    index -= 1
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.searchOperation(self, didAddResults: [ConsoleSearchResultViewModel(entity: self.entities[currentMatchIndex], occurrences: occurrences)])
                    }
                }
            }
            index += 1
        }
        DispatchQueue.main.async {
            self.delegate?.searchOperationDidFinish(self, hasMore: hasMore)
            if self.cutoff < 1000 {
                self.cutoff *= 2
            }
        }
    }

    // MARK: Cancellation

    private var isCancelled: Bool {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return _isCancelled
    }

    func cancel() {
        os_unfair_lock_lock(lock)
        _isCancelled = true
        os_unfair_lock_unlock(lock)
    }
}
