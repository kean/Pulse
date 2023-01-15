// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
protocol ConsoleSearchOperationDelegate: AnyObject { // Going old-school
    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel])
    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool)
}

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchOperation {
    private let searchText: String
    private let tokens: [ConsoleSearchToken]
    private var objectIDs: [NSManagedObjectID]
    private var index = 0
    private var cutoff = 10
    private let service: ConsoleSearchService
    private let context: NSManagedObjectContext
    private let lock: os_unfair_lock_t
    private var _isCancelled = false

    weak var delegate: ConsoleSearchOperationDelegate?

    init(objectIDs: [NSManagedObjectID],
         searchText: String,
         tokens: [ConsoleSearchToken],
         service: ConsoleSearchService,
         context: NSManagedObjectContext) {
        self.objectIDs = objectIDs
        self.searchText = searchText
        self.tokens = tokens
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
            if let entity = try? self.context.existingObject(with: objectIDs[index]),
               let result = self.search(entity) {
                found += 1
                if found > cutoff {
                    hasMore = true
                    index -= 1
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.searchOperation(self, didAddResults: [result])
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

    // TOOD: dynamic cast
    private func search(_ entity: NSManagedObject) -> ConsoleSearchResultViewModel? {
        guard let task = (entity as? LoggerMessageEntity)?.task else {
            return nil
        }
        return search(task)
    }

    // TODO: use on TextHelper instance
    // TODO: add remaining fields
    // TODO: what if URL matches? can we highlight the cell itself?
    private func search(_ task: NetworkTaskEntity) -> ConsoleSearchResultViewModel? {
        guard service.filter(task: task, tokens: tokens) else {
            return nil
        }
        // TODO: show occurence for filter still?
        guard searchText.count > 1 else {
            return ConsoleSearchResultViewModel(entity: task, occurences: [])
        }
        var occurences: [ConsoleSearchOccurence] = []
        occurences += service.search(.responseBody, in: task, searchText: searchText, options: .default)
        guard !occurences.isEmpty else {
            return nil
        }
        return ConsoleSearchResultViewModel(entity: task, occurences: occurences)
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