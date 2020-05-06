// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData

public final class LoggerMessageStore {
    public let container: NSPersistentContainer
    public let backgroundContext: NSManagedObjectContext

    /// Logs expiration interval
    public var logsExpirationInterval: TimeInterval

    public static let `default` = LoggerMessageStore(name: "com.github.kean.logger")

    /// Creates a `LoggerMessageStore` persisting using the given `NSPersistentContainer`.
    /// - Parameters:
    ///   - container: The `NSPersistentContainer` to be used for persistency.
    ///   - logsExpirationInterval: All logged messages older than the specified `TimeInterval` will be removed. Defaults to 7 days.
    public init(container: NSPersistentContainer, logsExpirationInterval: TimeInterval = 604800) {
        self.container = container
        self.backgroundContext = container.newBackgroundContext()
        self.logsExpirationInterval = logsExpirationInterval
        scheduleSweep()
    }

    /// Creates a `LoggerMessageStore` persisting to an `NSPersistentContainer` with the given name.
    /// - Parameters:
    ///   - name: The name of the `NSPersistentContainer` to be used for persistency.
    ///   - logsExpirationInterval: All logged messages older than the specified `TimeInterval` will be removed. Defaults to 7 days.
    public convenience init(name: String, logsExpirationInterval: TimeInterval = 604800) {
        let container = NSPersistentContainer(name: name, managedObjectModel: Self.model)
        container.loadPersistentStores { _, error in
            if let error = error {
                debugPrint("Failed to load persistent store with error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        self.init(container: container, logsExpirationInterval: logsExpirationInterval)
    }

    private func scheduleSweep() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            self?.sweep()
        }
    }
}

// MARK: - LoggerMessageStore (NSManagedObjectModel)
public extension LoggerMessageStore {
    /// Returns Core Data model used by the store.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let message = NSEntityDescription()
        message.name = "LoggerMessage"
        message.managedObjectClassName = LoggerMessage.self.description()
        message.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "level", type: .stringAttributeType),
            NSAttributeDescription(name: "label", type: .stringAttributeType),
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
}

// MARK: - LoggerMessageStore (Sweep)
extension LoggerMessageStore {
    func sweep() {
        let expirationInterval = logsExpirationInterval
        backgroundContext.perform {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "LoggerMessage")
            let dateTo = Date().addingTimeInterval(-expirationInterval)
            request.predicate = NSPredicate(format: "createdAt < %@", dateTo as NSDate)
            try? self.deleteMessages(fetchRequest: request)
        }
    }
}

// MARK: - LoggerMessageStore (Accessing Messages)

public extension LoggerMessageStore {
    /// Returns all recorded messages, least recent messages come first.
    func allMessages() throws -> [LoggerMessage] {
        let request = NSFetchRequest<LoggerMessage>(entityName: "LoggerMessage")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessage.createdAt, ascending: true)]
        return try container.viewContext.fetch(request)
    }

    /// Removes all of the previously recorded messages.
    func removeAllMessages() {
        backgroundContext.perform {
            try? self.deleteMessages(fetchRequest: LoggerMessage.fetchRequest())
        }
    }
}

// MARK: - LoggerMessageStore (Helpers)

private extension LoggerMessageStore {
    func deleteMessages(fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let result = try backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
        guard let ids = result?.result as? [NSManagedObjectID] else { return }

        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: ids],
            into: [backgroundContext, container.viewContext]
        )
    }
}

// MARK: - LoggerMessage

public final class LoggerMessage: NSManagedObject {
    @NSManaged public var createdAt: Date
    @NSManaged public var level: String
    @NSManaged public var label: String
    @NSManaged public var session: String
    @NSManaged public var text: String
}
