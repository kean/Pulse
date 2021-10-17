// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import PulseInternal

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

    /// Determines how often the messages are saved to the database. By default,
    /// 100 milliseconds - quickly enough, but avoiding too many individual writes.
    public var saveInterval: DispatchTimeInterval = .milliseconds(100)
    
    /// Size limit in bytes. `30 Mb` by default. The limit is approximate.
    public static var databaseSizeLimit: Int = 1024 * 1024 * 30

    /// Size limit in bytes. `200 Mb` by default.
    public static var blobsSizeLimit: Int = 1024 * 1024 * 200
    
    /// The default store.
    public static let `default` = LoggerStore.makeDefault()

    /// Returns a URL for the directory where all Pulse stores are located.
    /// The current store is located in the "./current" directory, the rest the stores
    /// are in "./archive".
    public static var logsURL: URL { URL.logs }

    var makeCurrentDate: () -> Date = { Date() }
    
    var onEvent: ((LoggerStoreEvent) -> Void)?

    private var isSaveScheduled = false
    
    private enum PulseDocument {
        case directory(blobs: BlobStore)
        case file(archive: IndexedArchive, manifest: LoggerStoreInfo)
        case empty
    }

    private static func makeDefault() -> LoggerStore {
        let storeURL = URL.logs.appendingPathComponent("current.pulse", isDirectory: true)
        let store = try? LoggerStore(storeURL: storeURL, options: [.create, .sweep])
        #if !os(macOS)
        if let store = store, #available(iOS 14.0, tvOS 14.0, watchOS 7.0, *) {
            RemoteLogger.shared.initialize(store: store)
        }
        #endif
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
        try? LoggerStore.loadStore(container: container)
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
        try
            LoggerStore.loadStore(container: container)
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
            store.setValue("DELETE" as NSString, forPragmaNamed: "journal_mode")
        }
        container.persistentStoreDescriptions = [store]
        return container
    }
    
    private static func loadStore(container: NSPersistentContainer) throws {
        var loadError: Error?
        container.loadPersistentStores { description, error in
            if let error = error {
                debugPrint("Failed to load persistent store \(description) with error: \(error)")
                loadError = error
            }
        }
        if let error = loadError {
            throw error
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
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
        let date = makeCurrentDate()
        perform {
            let message = Message(createdAt: date, label: label, level: level, message: message, metadata: metadata?.unpack(), session: LoggerSession.current.id.uuidString, file: file, function: function, line: line)
            self.makeMessageEntity(with: message)
            self.onEvent?(.saveMessage(message))
        }
    }
    
    /// Stores the given message.
    func storeMessage(_ message: Message) {
        perform {
            self._storeMessage(message)
        }
    }
    
    private func _storeMessage(_ message: Message) {
        makeMessageEntity(with: message)
    }
    
    /// Stores the network request.
    ///
    /// - note: If you want to store incremental updates to the task, use
    /// `NetworkLogger` instead.
    public func storeRequest(_ request: URLRequest, response: URLResponse?, error: Error?, data: Data?, metrics: URLSessionTaskMetrics? = nil, session: URLSession? = nil) {
        storeRequest(request, response: response, error: error, data: data, metrics: metrics.map(NetworkLoggerMetrics.init), session: session)
    }
    
    func storeRequest(_ request: URLRequest, response: URLResponse?, error: Error?, data: Data?, metrics: NetworkLoggerMetrics?, session: URLSession?) {
        let date = makeCurrentDate()
        perform {
            let message = NetworkMessage(
                createdAt: date,
                request: NetworkLoggerRequest(urlRequest: request),
                response: response.map(NetworkLoggerResponse.init),
                error: error.map(NetworkLoggerError.init),
                requestBody: request.httpBody ?? request.httpBodyStreamData(),
                responseBody: data,
                metrics: metrics,
                urlSession: session.map(NetworkLoggerURLSession.init),
                session: LoggerSession.current.id.uuidString
            )
            self._storeNetworkRequest(message)
            self.onEvent?(.saveNetworkMessage(message))
        }
    }
    
    func storeRequest(_ request: NetworkMessage) {
        perform {
            self._storeNetworkRequest(request)
        }
    }
    
    private func _storeNetworkRequest(_ summary: NetworkMessage) {
        let level: LoggerStore.Level
        let url = summary.request.url?.absoluteString
        var message = "\(summary.request.httpMethod ?? "–") \(url ?? "–")"
        if let error = summary.error {
            level = .error
            message += " \(error.code) \(error.localizedDescription)"
        } else {
            let statusCode = summary.response?.statusCode
            if let statusCode = statusCode, !(200..<400).contains(statusCode) {
                level = .error
            } else {
                level = .debug
            }
            message += " \(statusCode.map(descriptionForStatusCode) ?? "–")"
        }
        
        let messageObject = Message(createdAt: summary.createdAt, label: "network", level: level, message: message, metadata: nil, session: summary.session, file: "", function: "", line: 0)
        
        let messageEntity = self.makeMessageEntity(with: messageObject)
        let requestEntity = self.makeNetworkRequestEntity(summary, createdAt: summary.createdAt)
        messageEntity.request = requestEntity
        messageEntity.requestState = requestEntity.requestState
        requestEntity.message = messageEntity
    }
        
    @discardableResult
    private func makeMessageEntity(with message: Message) -> LoggerMessageEntity {
        let entity = LoggerMessageEntity(context: backgroundContext)
        entity.createdAt = message.createdAt
        entity.level = message.level.rawValue
        entity.levelOrder = message.level.order
        entity.label = message.label
        entity.session = message.session
        entity.text = message.message
        if let metadata = message.metadata, !metadata.isEmpty {
            entity.metadata = Set(metadata.map { key, value in
                let entity = LoggerMetadataEntity(context: backgroundContext)
                entity.key = key
                entity.value = value
                return entity
            })
        }
        entity.file = message.file
        entity.filename = (message.file as NSString).lastPathComponent
        entity.function = message.function
        entity.line = Int32(message.line)
        return entity
    }

    @discardableResult
    private func makeNetworkRequestEntity(_ summary: LoggerStore.NetworkMessage, createdAt: Date) -> LoggerNetworkRequestEntity {
        let entity = LoggerNetworkRequestEntity(context: backgroundContext)
        // Primary
        entity.createdAt = createdAt
        entity.session = LoggerSession.current.id.uuidString
        // Denormalized
        entity.url = summary.request.url?.absoluteString
        entity.host = summary.request.url?.host
        entity.httpMethod = summary.request.httpMethod
        entity.errorDomain = summary.error?.domain
        let errorCode = Int32(summary.error?.code ?? 0)
        entity.errorCode = errorCode
        let statusCode = Int32(summary.response?.statusCode ?? 0)
        entity.statusCode = statusCode
        entity.duration = summary.metrics?.taskInterval.duration ?? 0
        entity.contentType = summary.response?.headers["Content-Type"]
        entity.isCompleted = true
        let isFailure = errorCode != 0 || (statusCode != 0 && !(200..<400).contains(statusCode))
        entity.requestState = (isFailure ? LoggerNetworkRequestEntity.State.failure : .success).rawValue
        // Details
        entity.details = makeRequestDetails(summary)
        if case let .directory(store) = document {
            entity.requestBodyKey = store.storeData(summary.requestBody)
            entity.responseBodyKey = store.storeData(summary.responseBody)
        }
        return entity
    }

    @discardableResult
    private func makeRequestDetails(_ summary: LoggerStore.NetworkMessage) -> LoggerNetworkRequestDetailsEntity {
        let entity = LoggerNetworkRequestDetailsEntity(context: backgroundContext)
        let encoder = JSONEncoder()
        entity.request = try? encoder.encode(summary.request)
        entity.response = try? encoder.encode(summary.response)
        entity.error = try? encoder.encode(summary.error)
        entity.metrics = try? encoder.encode(summary.metrics)
        entity.urlSession =  try? encoder.encode(summary.urlSession)
        entity.requestBodySize = Int64(summary.requestBody?.count ?? 0)
        entity.responseBodySize = Int64(summary.responseBody?.count ?? 0)
        return entity
    }
    
    private func setNeedsSave() {
        guard !isSaveScheduled else { return }
        isSaveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + saveInterval) { [weak self] in
            self?.flush()
        }
    }
    
    // Internal for testing purposes.
    func flush(_ completion: (() -> Void)? = nil) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            if self.isSaveScheduled {
                try? _ExceptionCatcher.catchException {
                    try? self.backgroundContext.save()
                }
                self.isSaveScheduled = false
            }
            completion?()
        }
    }
    
    // MARK: Managing Pins
    
    /// Toggles pin for the give message.
    public func togglePin(for message: LoggerMessageEntity) {
        performChangesOnMain { _ in
            message.isPinned.toggle()
        }
    }
    
    /// Removes all pins.
    public func removeAllPins() {
        performChangesOnMain { context in
            let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
            request.fetchBatchSize = 250
            request.predicate = NSPredicate(format: "isPinned == YES")
            
            let messages: [LoggerMessageEntity] = (try? context.fetch(request)) ?? []
            for message in messages {
                message.isPinned = false
            }
        }
    }
    
    // MARK: Direct Modifiction
        
    /// Perform and save changes on the main queue.
    private func performChangesOnMain(_ closure: (NSManagedObjectContext) -> Void) {
        precondition(Thread.isMainThread)
        closure(container.viewContext)
        try? container.viewContext.save()
    }
    
    private func perform(_ changes: @escaping () -> Void) {
        guard !isReadonly else { return }
        backgroundContext.perform {
            changes()
            self.setNeedsSave()
        }
    }
    
    // MARK: Accessing Data

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
    public final class Message: Codable {
        public let createdAt: Date
        public let label: String
        public let level: LoggerStore.Level
        public let message: String
        public let metadata: [String: String]?
        public let session: String
        public let file: String
        public let function: String
        public let line: UInt
        
        public init(createdAt: Date, label: String, level: LoggerStore.Level, message: String, metadata: [String : String]?, session: String, file: String, function: String, line: UInt) {
            self.createdAt = createdAt
            self.label = label
            self.level = level
            self.message = message
            self.metadata = metadata
            self.session = session
            self.file = file
            self.function = function
            self.line = line
        }
    }
    
    public final class NetworkMessage: Codable {
        public let createdAt: Date
        public let request: NetworkLoggerRequest
        public let response: NetworkLoggerResponse?
        public let error: NetworkLoggerError?
        public let requestBody: Data?
        public let responseBody: Data?
        public let metrics: NetworkLoggerMetrics?
        public let urlSession: NetworkLoggerURLSession?
        public let session: String
        
        public init(createdAt: Date, request: NetworkLoggerRequest, response: NetworkLoggerResponse?, error: NetworkLoggerError?, requestBody: Data?, responseBody: Data?, metrics: NetworkLoggerMetrics?, urlSession: NetworkLoggerURLSession?, session: String) {
            self.createdAt = createdAt
            self.request = request
            self.response = response
            self.error = error
            self.requestBody = requestBody
            self.responseBody = responseBody
            self.metrics = metrics
            self.urlSession = urlSession
            self.session = session
        }
    }
    
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
        
        var order: Int16 {
            switch self {
            case .trace: return 0
            case .debug: return 1
            case .info: return 2
            case .notice: return 3
            case .warning: return 4
            case .error: return 5
            case .critical: return 6
            }
        }
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
            appInfo: .make(),
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
    func unpack() -> [String: String] {
        var entries = [String: String]()
        for (key, value) in self {
            switch value {
            case let .string(string): entries[key] = string
            case let .stringConvertible(string): entries[key] = string.description
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

private extension URLRequest {
	func httpBodyStreamData() -> Data? {
		guard let bodyStream = self.httpBodyStream else {
			return nil
		}
		
		// Will read 16 chars per iteration. Can use bigger buffer if needed
		let bufferSize: Int = 16
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)

		bodyStream.open()
		defer {
			buffer.deallocate()
			bodyStream.close()
		}
		
		var bodyStreamData = Data()
		
		while bodyStream.hasBytesAvailable {
			let readData = bodyStream.read(buffer, maxLength: bufferSize)
			bodyStreamData.append(buffer, count: readData)
		}
		
		return bodyStreamData
	}
}

enum LoggerStoreEvent {
    case saveMessage(LoggerStore.Message)
    case saveNetworkMessage(LoggerStore.NetworkMessage)
}
