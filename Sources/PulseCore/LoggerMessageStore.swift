// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData

public final class LoggerMessageStore {
    public let container: NSPersistentContainer
    public let backgroundContext: NSManagedObjectContext

    /// All logged messages older than the specified `TimeInterval` will be removed. Defaults to 7 days.
    public var logsExpirationInterval: TimeInterval = 604800

    public static let `default` = LoggerMessageStore(name: "com.github.kean.logger")

    var makeCurrentDate: () -> Date = { Date() }

    /// Creates a `LoggerMessageStore` persisting using the given `NSPersistentContainer`.
    /// - Parameters:
    ///   - container: The `NSPersistentContainer` to be used for persistency.
    public init(container: NSPersistentContainer) {
        self.container = container
        container.loadPersistentStores { description, error in
            if let error = error {
                debugPrint("Failed to load persistent store \(description) with error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        self.backgroundContext = container.newBackgroundContext()
        scheduleSweep()
    }

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
    public convenience init(storeURL: URL) {
        let container = NSPersistentContainer(name: storeURL.lastPathComponent, managedObjectModel: Self.model)
        let store = NSPersistentStoreDescription(url: storeURL)
        container.persistentStoreDescriptions = [store]
        self.init(container: container)
    }

    public func storeMessage(date: Date? = nil, label: String, level: Level, message: String, metadata: [String: MetadataValue]?, file: String, function: String, line: UInt) {
        let context = backgroundContext
        let date = date ?? makeCurrentDate()
        context.perform {
            self.makeMessageEntity(createdAt: date, label: label, level: level, message: message, metadata: metadata, file: file, function: function, line: line)
            try? context.save()
        }
    }

    func storeNetworkRequest(_ request: NetworkLoggerRequestSummary, createdAt: Date, level: Level, message: String) {
        let context = backgroundContext
        context.perform {
            let messageEntity =  self.makeMessageEntity(createdAt: createdAt, label: "network", level: level, message: message, metadata: nil, file: "", function: "", line: 0)
            let requestEntity = self.makeRequest(request, createdAt: createdAt)
            messageEntity.request = requestEntity
            requestEntity.message = messageEntity
            try? context.save()
        }
    }

    private func scheduleSweep() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            self?.sweep()
        }
    }
}

private extension LoggerMessageStore {
    @discardableResult
    func makeMessageEntity(createdAt: Date, label: String, level: Level, message: String, metadata: [String: MetadataValue]?, file: String, function: String, line: UInt) -> LoggerMessageEntity {
        let entity = LoggerMessageEntity(context: backgroundContext)
        entity.createdAt = createdAt
        entity.level = level.rawValue
        entity.label = label
        entity.session = LoggerSession.current.id.uuidString
        entity.text = String(describing: message)
        if let entries = metadata?.unpack(), !entries.isEmpty {
            entity.metadata = Set(entries.map { key, value in
                let entity = LoggerMetadataEntity(context: backgroundContext)
                entity.key = key
                entity.value = value
                return entity
            })
        }
        entity.file = file
        entity.function = function
        entity.line = Int32(line)
        return entity
    }

    @discardableResult
    func makeRequest(_ event: NetworkLoggerRequestSummary, createdAt: Date) -> LoggerNetworkRequestEntity {
        let entity = LoggerNetworkRequestEntity(context: backgroundContext)
        // Primary
        entity.createdAt = createdAt
        entity.session = LoggerSession.current.id.uuidString
        // Denormalized
        entity.url = event.request.url?.absoluteString
        entity.host = event.request.url?.host
        entity.httpMethod = event.request.httpMethod
        entity.errorDomain = event.error?.domain
        entity.errorCode = Int32(event.error?.code ?? 0)
        entity.statusCode = Int32(event.response?.statusCode ?? 0)
        // Details
        entity.details = makeRequestDetails(event)
        entity.requestBodyKey = event.requestBodyKey
        entity.responseBodyKey = event.responseBodyKey
        return entity
    }

    @discardableResult
    func makeRequestDetails(_ event: NetworkLoggerRequestSummary) -> LoggerNetworkRequestDetailsEntity {
        let entity = LoggerNetworkRequestDetailsEntity(context: backgroundContext)
        let encoder = JSONEncoder()
        entity.request = try? encoder.encode(event.request)
        entity.response = try? encoder.encode(event.response)
        entity.error = try? encoder.encode(event.error)
        entity.metrics = try? encoder.encode(event.metrics)
        return entity
    }
}

public extension LoggerMessageStore {
    enum MetadataValue {
        case string(String)
        case stringConvertible(CustomStringConvertible)
    }

    typealias Metadata = [String: MetadataValue]

    // Compatible with SwiftLog.Logger.Level
    @frozen enum Level: String, CaseIterable, Codable, Hashable {
        case trace
        case debug
        case info
        case notice
        case warning
        case error
        case critical
    }
}

// MARK: - LoggerMessageStore (Sweep)

extension LoggerMessageStore {
    func sweep() {
        let expirationInterval = logsExpirationInterval
        backgroundContext.perform {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "LoggerMessageEntity")
            let dateTo = self.makeCurrentDate().addingTimeInterval(-expirationInterval)
            request.predicate = NSPredicate(format: "createdAt < %@", dateTo as NSDate)
            try? self.deleteMessages(fetchRequest: request)
        }
    }
}

// MARK: - LoggerMessageStore (Accessing Messages)

public extension LoggerMessageStore {
    /// Returns all recorded messages, least recent messages come first.
    func allMessages() throws -> [LoggerMessageEntity] {
        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "LoggerMessageEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: true)]
        return try container.viewContext.fetch(request)
    }

    /// Removes all of the previously recorded messages.
    func removeAllMessages() {
        backgroundContext.perform {
            try? self.deleteMessages(fetchRequest: LoggerMessageEntity.fetchRequest())
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

// MARK: - Private

private extension Dictionary where Key == String, Value == LoggerMessageStore.MetadataValue {
    func unpack() -> [(String, String)] {
        var entries = [(String, String)]()
        for (key, value) in self {
            switch value {
            case let .string(string): entries.append((key, string))
            case let .stringConvertible(string): entries.append((key, string.description))
            }
        }
        return entries
    }
}
