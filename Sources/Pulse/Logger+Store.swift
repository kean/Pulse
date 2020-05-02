// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

public extension Logger {
    var store: Store {
        Store(container: container)
    }

    struct Store {
        let container: NSPersistentContainer

        /// Removes all of the previously recorded messages.
        public func removeAllMessages() throws {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "MessageEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try container.persistentStoreCoordinator.execute(deleteRequest, with: container.viewContext)
        }
    }
}
