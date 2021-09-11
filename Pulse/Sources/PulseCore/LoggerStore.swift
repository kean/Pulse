// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

/// `LoggerStore` persistently stores all of the logged messages, network
/// requests, and blobs. Use `.default` store to log messages.
public final class LoggerStore {
    /// The URL the store was initialized with.
    public let storeURL: URL

    /// Returns `true` if the store was opened with a Pulse archive (a document
    /// with `.pulse` extension). The archives are readonly.
    public let isReadonly: Bool

    /// Returns the store info (only available for archives).
    public private(set) var info: LoggerStoreInfo?

    /// Returns the Core Data container associated with the store.
    public let container: NSPersistentContainer

    /// Returns the background managed object context used for all write operations.
    public let backgroundContext: NSManagedObjectContext

    private let document: PulseDocument

    /// Size limit in bytes. `30 Mb` by default. The limit is approximate.
    public static var databaseSizeLimit: Int = 1024 * 1024 * 30

    /// Size limit in bytes. `200 Mb` by default.
    public static var blobsSizeLimit: Int = 1024 * 1024 * 200

    /// The default store.
    public static let `default` = LoggerStore.make(name: "current")

    /// Returns a URL for the directory where all Pulse stores are located.
    /// The current store is located in the "./current" directory, the rest the stores
    /// are in "./archive".
    public static var logsURL: URL { URL.logs }

    var makeCurrentDate: () -> Date = { Date() }

    private enum PulseDocument {
        case directory(blobs: BlobStore)
        case file(archive: IndexedArchive, manifest: LoggerStoreInfo)
        case empty
    }

    private static func make(name: String) -> LoggerStore {
        let storeURL = URL.logs.appendingPathComponent("\(name).pulse", isDirectory: true)
        let store = try? LoggerStore(storeURL: storeURL, options: [.create, .sweep])
        return store ?? LoggerStore(storeURL: storeURL, isEmpty: true)
    }

    // MARK: Initialization

    public struct Options: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// Creates store if the file is missing. The intermediate directories must
        /// already exist.
        public static let create = Options(rawValue: 1 << 0)

        /// Reduces store size when it reaches the size limit by by removing the least
        /// recently added messages and blobs.
        public static let sweep = Options(rawValue: 1 << 1)
    }

    /// An empty readonly placeholder store with no persistence.
    public static var empty: LoggerStore {
        LoggerStore(storeURL: URL.logs.appendingFilename("empty"), isEmpty: true)
    }

    /// Initializes the store with the given URL.
    ///
    /// There are two types of URLs that the store supports:
    /// - A plain directory with a Pulse database (optimized for writing)
    /// - A document with `.pulse` extension (readonly, archive)
    ///
    /// `Logger.default` is a plain directory optimized for writing. When you are
    /// ready to share the store, create a Pulse document using `archive()` or
    /// `copy(to:)` methods. The document format is optimized to use the least
    /// amount of space possible.
    ///
    /// - parameter storeURL: The store URL.
    /// - parameter options: By default, empty. To create a new store, pass `.create`
    /// option.
    public convenience init(storeURL: URL, options: Options = []) throws {
        var isDirectory: ObjCBool = ObjCBool(false)
        let fileExists = Files.fileExists(atPath: storeURL.path, isDirectory: &isDirectory)

        guard fileExists || options.contains(.create) else {
            throw LoggerStoreError.fileDoesntExist
        }

        if !fileExists || isDirectory.boolValue { // Working with a package
            try self.init(packageURL: storeURL, create: !fileExists, options: options)
        } else { // Working with a zip archive
            try self.init(archiveURL: storeURL)
        }
    }

    init(packageURL: URL, create: Bool, options: Options) throws {
        self.storeURL = packageURL

        if create {
            try Files.createDirectory(at: storeURL, withIntermediateDirectories: false, attributes: nil)
        }
        let databaseURL = storeURL.appendingFilename(databaseFileName)
        if !create {
            guard Files.fileExists(atPath: databaseURL.path) else {
                throw LoggerStoreError.storeInvalid
            }
        }
        let blobsURL = storeURL.appendingDirectory(blobsDirectoryName)
        if !Files.fileExists(atPath: blobsURL.path) {
            try Files.createDirectory(at: blobsURL, withIntermediateDirectories: false, attributes: nil)
        }

        self.container = LoggerStore.makeContainer(databaseURL: databaseURL, isViewing: false)
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.isReadonly = false
        self.document = .directory(blobs: BlobStore(path: blobsURL))

        if options.contains(.sweep) {
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
                self?.sweep()
            }
        }
    }

    init(archiveURL: URL) throws {
        self.storeURL = archiveURL

        guard let archive = IndexedArchive(url: storeURL) else {
            throw LoggerStoreError.storeInvalid
        }
        let manifest = try LoggerStoreInfo.make(archive: archive)
        let databaseURL = URL.temp.appendingFilename(manifest.id.uuidString)
        if !Files.fileExists(atPath: databaseURL.path) {
            guard let database = archive[databaseFileName] else {
                throw LoggerStoreError.storeInvalid
            }
            try archive.extract(database, to: databaseURL)
        }

        self.container = LoggerStore.makeContainer(databaseURL: databaseURL, isViewing: true)
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.isReadonly = true
        self.info = manifest
        self.document = .file(archive: archive, manifest: manifest)
    }

    init(storeURL: URL, isEmpty: Bool) {
        self.storeURL = storeURL
        self.isReadonly = true
        self.container = NSPersistentContainer(name: "EmptyStore", managedObjectModel: Self.model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, _ in }
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.document = .empty
    }

    private static func makeContainer(databaseURL: URL, isViewing: Bool) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: databaseURL.lastPathComponent, managedObjectModel: Self.model)
        let store = NSPersistentStoreDescription(url: databaseURL)
        if isViewing {
            store.setOption(NSNumber(value: true), forKey: NSReadOnlyPersistentStoreOption)
            store.setValue("DELETE" as NSString, forPragmaNamed: "journal_mode")
        }
        container.persistentStoreDescriptions = [store]

        container.loadPersistentStores { description, error in
            if let error = error {
                debugPrint("Failed to load persistent store \(description) with error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        return container
    }

    private static func makeBackgroundContext(for container: NSPersistentContainer) -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.undoManager = nil
        return context
    }
}

// MARK: - LoggerStore (Storing Messages)

extension LoggerStore {
    /// Stores the given message.
    public func storeMessage(label: String, level: Level, message: String, metadata: [String: MetadataValue]?, file: String = #file, function: String = #function, line: UInt = #line) {
        let context = backgroundContext
        let date = makeCurrentDate()
        context.perform {
            self.makeMessageEntity(createdAt: date, label: label, level: level, message: message, metadata: metadata, file: file, function: function, line: line)
            try? context.save()
        }
    }
    
    /// Stores the completed network request.
    ///
    /// - note: If you want to store incremental updates to the task, use
    /// `NetworkLogger` instead.
    public func storeRequest(_ request: URLRequest, response: URLResponse?, error: Error?, data: Data?, metrics: URLSessionTaskMetrics? = nil) {
        let context = NetworkLogger.TaskContext()
        context.request = request
        context.response = response
        context.error = error
        context.data = data ?? Data()
        context.metrics = metrics.map(NetworkLoggerMetrics.init)
        
        storeNetworkRequest(context)
    }

    func storeNetworkRequest(_ context: NetworkLogger.TaskContext) {
        let date = makeCurrentDate()
        backgroundContext.perform {
            self.storeNetworkRequest(context, date: date)
            try? self.backgroundContext.save()
        }
    }

    private func storeNetworkRequest(_ context: NetworkLogger.TaskContext, date: Date) {
        guard let urlRequest = context.request else { return }

        let summary = NetworkLoggerRequestSummary(
            request: NetworkLoggerRequest(urlRequest: urlRequest),
            response: context.response.map(NetworkLoggerResponse.init),
            error: context.error.map(NetworkLoggerError.init),
            requestBody: urlRequest.httpBody,
            responseBody: context.data,
            metrics: context.metrics
        )

        let level: LoggerStore.Level
        let url = urlRequest.url?.absoluteString
        var message = "\(urlRequest.httpMethod ?? "–") \(url ?? "–")"
        if let error = context.error {
            level = .error
            message += " \((error as NSError).code) \(error.localizedDescription)"
        } else {
            let statusCode = (context.response as? HTTPURLResponse)?.statusCode
            if let statusCode = statusCode, !(200..<400).contains(statusCode) {
                level = .error
            } else {
                level = .debug
            }
            message += " \(statusCode.map(descriptionForStatusCode) ?? "–")"
        }

        storeNetworkRequest(summary, createdAt: date, level: level, message: message)
    }

    private func storeNetworkRequest(_ summary: NetworkLoggerRequestSummary, createdAt: Date, level: Level, message: String) {
        let messageEntity = self.makeMessageEntity(createdAt: createdAt, label: "network", level: level, message: message, metadata: nil, file: "", function: "", line: 0)
        let requestEntity = self.makeRequest(summary, createdAt: createdAt)
        messageEntity.request = requestEntity
        requestEntity.message = messageEntity
    }

    @discardableResult
    private func makeMessageEntity(createdAt: Date, label: String, level: Level, message: String, metadata: [String: MetadataValue]?, file: String, function: String, line: UInt) -> LoggerMessageEntity {
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
    private func makeRequest(_ summary: NetworkLoggerRequestSummary, createdAt: Date) -> LoggerNetworkRequestEntity {
        let entity = LoggerNetworkRequestEntity(context: backgroundContext)
        // Primary
        entity.createdAt = createdAt
        entity.session = LoggerSession.current.id.uuidString
        // Denormalized
        entity.url = summary.request.url?.absoluteString
        entity.host = summary.request.url?.host
        entity.httpMethod = summary.request.httpMethod
        entity.errorDomain = summary.error?.domain
        entity.errorCode = Int32(summary.error?.code ?? 0)
        entity.statusCode = Int32(summary.response?.statusCode ?? 0)
        entity.duration = summary.metrics?.taskInterval.duration ?? 0
        entity.isCompleted = true
        // Details
        entity.details = makeRequestDetails(summary)
        if case let .directory(store) = document {
            entity.requestBodyKey = store.storeData(summary.requestBody)
            entity.responseBodyKey = store.storeData(summary.responseBody)
        }
        return entity
    }

    @discardableResult
    private func makeRequestDetails(_ summary: NetworkLoggerRequestSummary) -> LoggerNetworkRequestDetailsEntity {
        let entity = LoggerNetworkRequestDetailsEntity(context: backgroundContext)
        let encoder = JSONEncoder()
        entity.request = try? encoder.encode(summary.request)
        entity.response = try? encoder.encode(summary.response)
        entity.error = try? encoder.encode(summary.error)
        entity.metrics = try? encoder.encode(summary.metrics)
        entity.requestBodySize = Int64(summary.requestBody?.count ?? 0)
        entity.responseBodySize = Int64(summary.responseBody?.count ?? 0)
        return entity
    }

    /// Returns blob data for the given key.
    public func getData(forKey key: String) -> Data? {
        switch document {
        case let .file(archive, _):
            return archive.dataForEntry("blobs/\(key)")
        case let .directory(store):
            return store.getData(for: key)
        case .empty:
            return nil
        }
    }
}

extension LoggerStore {
    public enum MetadataValue {
        case string(String)
        case stringConvertible(CustomStringConvertible)
    }

    public typealias Metadata = [String: MetadataValue]

    // Compatible with SwiftLog.Logger.Level
    @frozen public enum Level: String, CaseIterable, Codable, Hashable {
        case trace
        case debug
        case info
        case notice
        case warning
        case error
        case critical
    }
}

// MARK: - LoggerStore (Accessing Messages)

extension LoggerStore {
    /// Returns all recorded messages, least recent messages come first.
    public func allMessages() throws -> [LoggerMessageEntity] {
        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "LoggerMessageEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: true)]
        return try container.viewContext.fetch(request)
    }

    /// Returns all recorded network requests, least recent messages come first.
    public func allNetworkRequests() throws -> [LoggerNetworkRequestEntity] {
        let request = NSFetchRequest<LoggerNetworkRequestEntity>(entityName: "LoggerNetworkRequestEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerNetworkRequestEntity.createdAt, ascending: true)]
        return try container.viewContext.fetch(request)
    }

    /// Removes all of the previously recorded messages.
    public func removeAll() {
        backgroundContext.perform(_removeAll)
    }

    private func _removeAll() {
        switch document {
        case .directory(let blobs):
            try? deleteMessages(fetchRequest: LoggerMessageEntity.fetchRequest())
            blobs.removeAll()
        case .file, .empty:
            break // Do nothing, readonly
        }
    }

    private func deleteMessages(fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws {
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

// MARK: - LoggerStore (Archive and Copy)

extension LoggerStore {
    /// Creates a copy of the current store at the given URL. The created copy
    /// has `.pulse` extension (actually a `.zip` archive).
    ///
    /// The destination directory must already exist. But if the file at the
    /// destination URL already exists, throws an error.
    ///
    /// Thread-safe. But must not be called inside the `backgroundContext` queue.
    @discardableResult
    public func copy(to targetURL: URL) throws -> LoggerStoreInfo {
        switch document {
        case .directory(let blobs):
            return try backgroundContext.tryPerform {
                try copy(to: targetURL, blobs: blobs)
            }
        case .file(_, let manifest):
            try Files.copyItem(at: storeURL, to: targetURL)
            return manifest
        case .empty:
            throw LoggerStoreError.storeInvalid
        }
    }

    private func copy(to targetURL: URL, blobs: BlobStore) throws -> LoggerStoreInfo {
        let tempURL = URL.temp.appendingPathComponent(UUID().uuidString, isDirectory: true)
        Files.createDirectoryIfNeeded(at: tempURL)
        do {
            return try copy(to: targetURL, tempURL: tempURL, blobs: blobs)
        } catch {
            try? Files.removeItem(at: tempURL)
            throw error
        }
    }

    private func copy(to targetURL: URL, tempURL: URL, blobs: BlobStore) throws -> LoggerStoreInfo {
        // Create copy of the store
        let databaseURL = tempURL.appendingPathComponent(databaseFileName, isDirectory: false)
        try container.persistentStoreCoordinator.createCopyOfStore(at: databaseURL)

        // Create copy of the blobs
        let blobsURL = tempURL.appendingPathComponent(blobsDirectoryName, isDirectory: true)
        try blobs.copyContents(to: blobsURL)

        // Create description
        let databaseAttributes = try Files.attributesOfItem(atPath: databaseURL.path)
        let currentDatabaseAttributes = try Files.attributesOfItem(atPath: storeURL.appendingPathComponent(databaseFileName).path)
        let manifest = LoggerStoreInfo(
            id: UUID(),
            device: .make(),
            storeVersion: currentStoreVersion,
            messageCount: try messageCount(),
            requestCount: try networkRequestsCount(),
            databaseSize: (databaseAttributes[.size] as? Int64) ?? 00, // Right-side should never happen
            blobsSize: Int64(blobs.totalSize),
            createdDate: (currentDatabaseAttributes[.creationDate] as? Date) ?? Date(),
            modifiedDate: (currentDatabaseAttributes[.modificationDate] as? Date) ?? Date(),
            archivedDate: Date()
        )
        let descriptionURL = tempURL.appendingPathComponent(manifestFileName, isDirectory: false)
        try JSONEncoder().encode(manifest).write(to: descriptionURL)

        // Archive and add .pulse extension
        try Files.zipItem(at: tempURL, to: targetURL, shouldKeepParent: false, compressionMethod: .deflate)

        return manifest
    }

    private func messageCount() throws -> Int {
        try container.viewContext.fetch(LoggerMessageEntity.fetchRequest()).count
    }

    private func networkRequestsCount() throws -> Int {
        try container.viewContext.fetch(LoggerNetworkRequestEntity.fetchRequest()).count
    }
}

// MARK: - LoggerStore (Sweep)

extension LoggerStore {
    public func sweep() {
        backgroundContext.perform { try? self._sweep() }
    }

    private func _sweep() throws {
        let attributes = try Files.attributesOfItem(atPath: storeURL.appendingFilename(databaseFileName).path)
        let size = attributes[.size] as? Int64 ?? 0

        guard size > LoggerStore.databaseSizeLimit else {
            return // All good, no need to perform any work.
        }

        // Get the date form which to delete entities
        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "LoggerMessageEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)]
        let messages: [LoggerMessageEntity] = try backgroundContext.fetch(request)

        let count = messages.count
        guard count > 10 else { return } // Sanity check

        // Actually delete
        let dateTo = messages[count / 2].createdAt
        let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LoggerMessageEntity")
        deleteRequest.predicate = NSPredicate(format: "createdAt < %@", dateTo as NSDate)
        try self.deleteMessages(fetchRequest: deleteRequest)
    }
}

// MARK: - Constants

private let currentStoreVersion = "1.0.0"
let manifestFileName = "manifest.json"
private let databaseFileName = "logs.sqlite"
private let blobsDirectoryName = "blobs"

private extension Dictionary where Key == String, Value == LoggerStore.MetadataValue {
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

public enum LoggerStoreError: Error, LocalizedError {
    case fileDoesntExist
    case storeInvalid
    case documentIsReadonly
    case unknownError

    public var errorDescription: String? {
        switch self {
        case .fileDoesntExist: return "File doesn't exist"
        case .storeInvalid: return "Store format is invalid"
        case .documentIsReadonly: return "Document is readonly"
        case .unknownError: return "Unexpected error"
        }
    }
}
