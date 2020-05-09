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

    let queue = DispatchQueue(label: "com.github.pulse.logger-message-store")
    private var impl: LoggerMessageStoreImpl?
    private var isInsertErrorReported = false

    private var buffer = [MessageItem]()

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
            self.impl = try LoggerMessageStoreImpl(storeURL: storeURL)
        } catch {
            debugPrint("Failed to open a database at \(storeURL) with \(error)")
        }
        scheduleSweep()
    }

    private func scheduleSweep() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            #warning("TODO: implement")
//            self?.sweep()
        }
    }

    func insert(message: MessageItem) {
        #warning("TEMP")
//        queue.async {
            do {
                #warning("TODO: dump every 1 second")
                self.buffer.append(message)
//                if self.buffer.count == 1000 {
                    try self.impl?.insert(messages: self.buffer)
                    self.buffer = []
//                }
            } catch {
                guard !self.isInsertErrorReported else { return }
                self.isInsertErrorReported = true
                debugPrint("Failed to log message with error \(error)")
            }
//        }
    }

    func allMessages() throws -> [MessageItem] {
        guard let impl = impl else { return [] }
        do {
            return try impl.allMessages()
        } catch {
            return []
        }
    }
}

private final class LoggerMessageStoreImpl {
    var makeCurrentDate: () -> Date = { Date() }

    private var db: Database

    // Compiled statements.
    private var insertMessage: Statement!
    private var insertMetadata: Statement!

    public init(storeURL: URL) throws {
        // Prefer speed over data integrity
        self.db = try Database(url: storeURL, pragmas: [
            "synchronous": "OFF",
            "journal_mode": "OFF",
            "locking_mode": "EXCLUSIVE"
        ])
        try createTables()
    }

    private func createTables() throws {
        // TODO: replace Session VARCHAR with primary key
        try db.execute("""
        CREATE TABLE Messages
        (
            Id INTEGER PRIMARY KEY NOT NULL,
            CreatedAt DOUBLE,
            Level VARCHAR,
            Label VARCHAR,
            Session VARCHAR,
            Text VARCHAR,
            File VARCHAR,
            Function VARCHAR,
            Line INTEGER
        )
        """)

        try db.execute("""
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

    func insert(messages: [MessageItem]) throws {
//        try db.beginTransaction()

        for message in messages {
            let messageId = try db.insert("""
            INSERT INTO Messages
            (
                CreatedAt, Level, Label, Session, Text, File, Function, Line
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, [
                .timestamp(message.createdAt),
                .string(message.level),
                .string(message.label),
                .string(message.session),
                .string(message.text),
                .string(message.file),
                .string(message.function),
                .int(message.line)
            ])

            for metadata in message.metadata {
                try db.insert("""
                INSERT INTO Metadata
                (
                    Key, Value, MessageId
                )
                VALUES (?, ?, ?)
                """, [
                    .string(metadata.key),
                    .string(metadata.value),
                    .int(Int32(messageId))
                ])
            }
        }

//        try db.endTransaction()
    }

    /// Returns all recorded messages, least recently added messages come first.
    func allMessages() throws -> [MessageItem] {
        let messages = try db.select("""
        SELECT Id, CreatedAt, Level, Label, Session, Text, File, Function, Line
        FROM Messages
        ORDER BY CreatedAt ASC
        """) {
            MessageItem(id: $0[0], createdAt: $0[1], level: $0[2], label: $0[3], session: $0[4], text: $0[5], metadata: [], file: $0[6], function: $0[7], line: Int32($0[8]))
        }

        #warning("TODO: optimize by indexing CreatedAt")

        #warning("TODO: fill metadata")
//
//        let messages = try statement.select {
//            MessageItem(id: $0[0], createdAt: $0[1], level: $0[2], label: $0[3], session: $0[4], text: $0[5], metadata: [], file: $0[6], function: $0[7], line: Int32($0[8]))
//        }

        return messages
    }
}

//// MARK: - LoggerMessageStore (Sweep)
#warning("TODO: reimplement")
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


public struct MessageItem {
    public var id: Int
    public var createdAt: Date
    public var level: String
    public var label: String
    public var session: String
    public var text: String
    public var metadata: [MetadataItem]
    public var file: String
    public var function: String
    public var line: Int32
}

public struct MetadataItem {
    public var key: String
    public var value: String
}
