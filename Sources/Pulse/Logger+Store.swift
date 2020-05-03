// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

public extension Logger {
    var store: Store {
        Store(container: container, context: backgroundContext)
    }

    struct Store {
        public let container: NSPersistentContainer
        public let context: NSManagedObjectContext

        public init(container: NSPersistentContainer, context: NSManagedObjectContext) {
            self.container = container
            self.context = context
        }

        /// Removes all of the previously recorded messages.
        public func removeAllMessages() throws {
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = MessageEntity.fetchRequest()
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs

            let result = try context.execute(deleteRequest)

            guard let deleteResult = result as? NSBatchDeleteResult,
                let ids = deleteResult.result as? [NSManagedObjectID]
                else { return }

            let changes = [NSDeletedObjectsKey: ids]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        }
    }
}
