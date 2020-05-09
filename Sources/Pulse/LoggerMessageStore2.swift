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

    private var handle: OpaquePointer { return _handle! }
    private var _handle: OpaquePointer? = nil

    private let queue = DispatchQueue(label: "com.github.pulse.logger-message-store")

    var error: Error?

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
        #warning("TODO: connect to database")
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(storeURL.absoluteString, &_handle, flags, nil)
        if status != SQLITE_OK {
            let error = Error(code: status, handle: handle)
            self.error = error
            debugPrint("Failed to open connection with error: \(error)")
        }
        scheduleSweep()
    }

    deinit {
        sqlite3_close(handle)
    }

    private func scheduleSweep() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            #warning("TODO: implement")
//            self?.sweep()
        }
    }
}

extension LoggerMessageStore2 {
    struct Error: Swift.Error {
        let code: Int32
        let message: String

        var localizedDescription: String {
            return message
        }

        init(code: Int32, handle: OpaquePointer) {
            self.code = code
            self.message = String(cString: sqlite3_errmsg(handle))
        }
    }
}

// MARK: - LoggerMessageStore (Scheme)

private extension LoggerMessageStore {
    func create() {

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
