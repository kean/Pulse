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
        queue.asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            try? self?.sweep()
        }
    }

    func sweep() throws {
        let dateTo = makeCurrentDate().addingTimeInterval(-logsExpirationInterval)
        try impl?.sweep(dateTo: dateTo)
    }

    func store(message: MessageItem) {
        #warning("TEMP")
        queue.async {
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
        }
    }

    func insert(messages: [MessageItem]) throws {
        try impl?.insert(messages: messages)
    }

    func allMessages() throws -> [MessageItem] {
        guard let impl = impl else { return [] }
        do {
            return try impl.allMessages()
        } catch {
            return []
        }
    }

    #warning("TODO: make public?")
    func close() {
        try? impl?.db.close()
    }
}

private final class LoggerMessageStoreImpl {
    var makeCurrentDate: () -> Date = { Date() }

    var db: SQLConnection

    #warning("TODO: cache SQL statements")

    public init(storeURL: URL) throws {
        // Prefer speed over data integrity
        var options = SQLConnection.Options()
        options.threadingMode = .multithreaded

        self.db = try SQLConnection(location: .disk(url: storeURL), options: options)
        try db.execute("PRAGMA synchronous = OFF")
        try db.execute("PRAGMA journal_mode = OFF")
        try db.execute("PRAGMA locking_mode = EXCLUSIVE")
        try createTables()
    }

    private func createTables() throws {
        // TODO: replace Session VARCHAR with primary key
        try db.execute("""
        CREATE TABLE IF NOT EXISTS Messages
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
        CREATE TABLE IF NOT EXISTS Metadata
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
            try db.prepare("""
            INSERT INTO Messages
            (
                CreatedAt, Level, Label, Session, Text, File, Function, Line
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """)
                .bind(message.createdAt, message.level, message.label, message.session, message.text, message.file, message.function, message.line)
                .execute()

            let messageId = db.lastInsertRowID

            for metadata in message.metadata {
                try db.prepare("""
                INSERT INTO Metadata
                (
                    Key, Value, MessageId
                )
                VALUES (?, ?, ?)
                """)
                    .bind(metadata.key, metadata.value, messageId)
                    .execute()
            }
        }

//        try db.endTransaction()
    }

    /// Returns all recorded messages, least recently added messages come first.
    func allMessages() throws -> [MessageItem] {
        var messages = try db.prepare("""
        SELECT Id, CreatedAt, Level, Label, Session, Text, File, Function, Line
        FROM Messages
        ORDER BY CreatedAt ASC
        """).rows(MessageItem.self)

        #warning("TODO: add indexes")

        let getMetadata = try db.prepare("""
        SELECT Key, Value
        FROM Metadata
        WHERE MessageId = (?)
        """)

        for index in messages.indices {
            messages[index].metadata = try getMetadata
                .bind(messages[index].id)
                .rows(MetadataItem.self)
            try getMetadata.reset()
        }

        return messages
    }

    #warning("TODO: move to a background queue")
    func sweep(dateTo: Date) throws {
        try db.prepare("""
        DELETE FROM Messages
        WHERE createdAt < (?)
        """)
            .bind(dateTo)
            .execute()
    }

    #warning("TODO: reimplement")
    /// Returns all recorded messages, least recent messages come first.

    /// Removes all of the previously recorded messages.
//    func removeAllMessages() {
//        backgroundContext.perform {
//            try? self.deleteMessages(fetchRequest: MessageEntity.fetchRequest())
//        }
//    }
}

// MARK: - Rows

extension MessageItem: SQLRowDecodable {
    init(row: SQLRow) throws {
        self.id = row[0]
        self.createdAt = row[1]
        self.level = row[2]
        self.label = row[3]
        self.session = row[4]
        self.text = row[5]
        self.metadata = []
        self.file = row[6]
        self.function = row[7]
        self.line = row[8]
    }
}

extension MetadataItem: SQLRowDecodable {
    init(row: SQLRow) throws {
        self.key = row[0]
        self.value = row[1]
    }
}

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
