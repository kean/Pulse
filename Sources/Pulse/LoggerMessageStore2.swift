// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import SQLite3

public final class LoggerMessageStore2 {
    /// All logged messages older than the specified `TimeInterval` will be removed. Defaults to 7 days.
    public var logsExpirationInterval: TimeInterval = 604800

    public static let `default` = LoggerMessageStore2(name: "com.github.kean.logger")

    var makeCurrentDate: () -> Date = { Date() }

    private let queue = DispatchQueue(label: "com.github.pulse.logger-message-store")
    private var db: Database?

    /// Creates a `LoggerMessageStore` persisting to an `NSPersistentContainer` with the given name.
    /// - Parameters:
    ///   - name: The name of the `NSPersistentContainer` to be used for persistency.
    /// By default, the logger stores logs in Library/Logs directory which is
    /// excluded from the backup.
    public convenience init(name: String) {
        var logsUrl = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs", isDirectory: true) ?? URL(fileURLWithPath: "/dev/null")

        let logsPath = logsUrl.absoluteString

        if !FileManager.default.fileExists(atPath: logsPath) {
            try? FileManager.default.createDirectory(at: logsUrl, withIntermediateDirectories: true, attributes: [:])
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? logsUrl.setResourceValues(resourceValues)
        }

        let storeURL = logsUrl.appendingPathComponent("\(name).sqlite", isDirectory: false)
        self.init(storeURL: storeURL)
    }

    /// - storeURL: The storeURL.
    ///
    /// - warning: Make sure the directory used in storeURL exists.
    public init(storeURL: URL) {
        do {
            self.db = try Database(url: storeURL)
            try createTables()
        } catch {
            debugPrint("Failed to open a database at \(storeURL) with \(error)")
        }
        scheduleSweep()
    }

    private func createTables() throws {
        // TODO: replace Session VARCHAR with primary key
        try db?.create("""
        CREATE TABLE Messages
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            CreatedAt TIMESTAMP,
            Level CHAR(8),
            Label VARCHAR,
            Session VARCHAR,
            Text VARCHAR,
            File VARCHAR,
            Function VARCHAR,
            Line INTEGER
        )
        """)

        try db?.create("""
        CREATE TABLE Metadata
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            Key VARCHAR,
            Value VARCHAR,
            MessageId INTEGER,
            FOREIGN KEY(MessageId) REFERENCES Messages(Id)
        )
        """)
    }

    private func scheduleSweep() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            #warning("TODO: implement")
//            self?.sweep()
        }
    }
}

//
//// MARK: - LoggerMessageStore (NSManagedObjectModel)
//
//public extension LoggerMessageStore2 {
//    /// Returns Core Data model used by the store.
//    static let model: NSManagedObjectModel = {
//        let model = NSManagedObjectModel()
//
//        let message = NSEntityDescription(name: "MessageEntity", class: MessageEntity.self)
//        let metadata = NSEntityDescription(name: "MetadataEntity", class: MetadataEntity.self)
//
//        do {
//            let key = NSAttributeDescription(name: "key", type: .stringAttributeType)
//            let value = NSAttributeDescription(name: "value", type: .stringAttributeType)
//            metadata.properties = [key, value]
//        }
//
//        do {
//            let createdAt = NSAttributeDescription(name: "createdAt", type: .dateAttributeType)
//            let level = NSAttributeDescription(name: "level", type: .stringAttributeType)
//            let label = NSAttributeDescription(name: "label", type: .stringAttributeType)
//            let session = NSAttributeDescription(name: "session", type: .stringAttributeType)
//            let text = NSAttributeDescription(name: "text", type: .stringAttributeType)
//            let metadata = NSRelationshipDescription.oneToMany(name: "metadata", entity: metadata)
//            let file = NSAttributeDescription(name: "file", type: .stringAttributeType)
//            let function = NSAttributeDescription(name: "function", type: .stringAttributeType)
//            let line = NSAttributeDescription(name: "line", type: .integer32AttributeType)
//            message.properties = [createdAt, level, label, session, text, metadata, file, function, line]
//        }
//
//        model.entities = [message, metadata]
//        return model
//    }()
//}
//
//private extension NSEntityDescription {
//    convenience init<T>(name: String, class: T.Type) where T: NSManagedObject {
//        self.init()
//        self.name = name
//        self.managedObjectClassName = T.self.description()
//    }
//}
//
//private extension NSAttributeDescription {
//    convenience init(name: String, type: NSAttributeType) {
//        self.init()
//        self.name = name
//        self.attributeType = type
//    }
//}
//
//private extension NSRelationshipDescription {
//    static func oneToMany(name: String, deleteRule: NSDeleteRule = .cascadeDeleteRule, entity: NSEntityDescription) -> NSRelationshipDescription {
//        let relationship =  NSRelationshipDescription()
//        relationship.name = name
//        relationship.deleteRule = deleteRule
//        relationship.destinationEntity = entity
//        relationship.maxCount = 0
//        relationship.minCount = 0
//        return relationship
//    }
//}
//// MARK: - LoggerMessageStore (Sweep)
//
//extension LoggerMessageStore2 {
//    func sweep() {
//        let expirationInterval = logsExpirationInterval
//        backgroundContext.perform {
//            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "MessageEntity")
//            let dateTo = self.makeCurrentDate().addingTimeInterval(-expirationInterval)
//            request.predicate = NSPredicate(format: "createdAt < %@", dateTo as NSDate)
//            try? self.deleteMessages(fetchRequest: request)
//        }
//    }
//}
//
//// MARK: - LoggerMessageStore (Accessing Messages)
//
//public extension LoggerMessageStore2 {
//    /// Returns all recorded messages, least recent messages come first.
//    func allMessages() throws -> [MessageEntity] {
//        let request = NSFetchRequest<MessageEntity>(entityName: "MessageEntity")
//        request.sortDescriptors = [NSSortDescriptor(keyPath: \MessageEntity.createdAt, ascending: true)]
//        return try container.viewContext.fetch(request)
//    }
//
//    /// Removes all of the previously recorded messages.
//    func removeAllMessages() {
//        backgroundContext.perform {
//            try? self.deleteMessages(fetchRequest: MessageEntity.fetchRequest())
//        }
//    }
//}
//
//// MARK: - LoggerMessageStore (Helpers)
//
//private extension LoggerMessageStore2 {
//    func deleteMessages(fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws {
//        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
//        deleteRequest.resultType = .resultTypeObjectIDs
//
//        let result = try backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
//        guard let ids = result?.result as? [NSManagedObjectID] else { return }
//
//        NSManagedObjectContext.mergeChanges(
//            fromRemoteContextSave: [NSDeletedObjectsKey: ids],
//            into: [backgroundContext, container.viewContext]
//        )
//    }
//}
