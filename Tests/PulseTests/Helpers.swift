// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
import Foundation
import CoreData
@testable import Pulse

extension XCTestCase {
    func flush(store: LoggerMessageStore) {
        let flushCompleted = expectation(description: "Flush Completed")
        store.backgroundContext.perform {
            flushCompleted.fulfill()
        }
        wait(for: [flushCompleted], timeout: 10)
    }
}

extension LoggerMessageStore {
    func removeStores() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
    }

    func destroyStores() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.destroyPersistentStore(at: store.url!, ofType: NSSQLiteStoreType, options: [:])
        }
    }
}
