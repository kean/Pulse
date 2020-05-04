// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

// MARK: - Logger.Store

public extension Logger {
    final class Store {
        public let container: NSPersistentContainer
        /// Background context which can be used for writing.
        public let backgroundContext: NSManagedObjectContext

        public init(container: NSPersistentContainer) {
            self.container = container
            self.backgroundContext = container.newBackgroundContext()
        }

        public convenience init(name: String) {
            let container = NSPersistentContainer(name: name, managedObjectModel: Logger.Store.model)
            container.loadPersistentStores { _, error in
                if let error = error {
                    debugPrint("Failed to load persistent store with error: \(error)")
                }
            }
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

            self.init(container: container)
        }
    }
}

// MARK: - Logger.Store (NSManagedObjectModel)

public extension Logger.Store {
    /// Returns Core Data model used by the store.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let message = NSEntityDescription()
        message.name = "LoggerMessage"
        message.managedObjectClassName = LoggerMessage.self.description()
        message.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "level", type: .stringAttributeType),
            NSAttributeDescription(name: "system", type: .stringAttributeType),
            NSAttributeDescription(name: "category", type: .stringAttributeType),
            NSAttributeDescription(name: "session", type: .stringAttributeType),
            NSAttributeDescription(name: "text", type: .stringAttributeType)
        ]

        model.entities = [message]
        return model
    }()
}

private extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType) {
        self.init()
        self.name = name
        self.attributeType = type
    }

    convenience init(_ closure: (NSAttributeDescription) -> Void) {
        self.init()
        closure(self)
    }
}

// MARK: - Sweep (Sweep)

extension Logger.Store {
    func sweep(expirationInterval: TimeInterval) {
        container.performBackgroundTask { context in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "LoggerMessage")
            let dateTo = Date().addingTimeInterval(-expirationInterval)
            request.predicate = NSPredicate(format: "createdAt < %@", dateTo as NSDate)
            try? self.deleteMessages(fetchRequest: request, context: context)
        }
    }
}

// MARK: - Logger.Store (Accessing Messages)

public extension Logger.Store {

    /// Returns all recorded messages, least recent messages come first.
    func allMessage() throws -> [LoggerMessage] {
        let request = NSFetchRequest<LoggerMessage>(entityName: "LoggerMessage")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessage.createdAt, ascending: true)]
        return try container.viewContext.fetch(request)
    }

    /// Removes all of the previously recorded messages.
    func removeAllMessages() {
        container.performBackgroundTask { context in
            try? self.deleteMessages(fetchRequest: LoggerMessage.fetchRequest(), context: context)
        }
    }
}

// MARK: - Logger.Store (Helpers)

private extension Logger.Store {
    func deleteMessages(fetchRequest: NSFetchRequest<NSFetchRequestResult>, context: NSManagedObjectContext) throws {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
        guard let ids = result?.result as? [NSManagedObjectID] else { return }

        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: ids],
            into: [container.viewContext]
        )
    }
}

// MARK: - LoggerMessage

public final class LoggerMessage: NSManagedObject {
    @NSManaged public var createdAt: Date
    @NSManaged public var level: String
    @NSManaged public var system: String
    @NSManaged public var category: String
    @NSManaged public var session: String
    @NSManaged public var text: String
}
