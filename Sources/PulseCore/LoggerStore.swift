// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Combine

/// Persistently stores logs, network requests, and response blobs.
///
/// The recommended way to use the store is by adding the `Pulse` module and using
/// it with the Swift Logging system ([SwiftLog](https://github.com/apple/swift-log)).
///
/// ```swift
/// import Pulse
/// import Logging
///
/// LoggingSystem.bootstrap(PersistentLogHandler.init)
/// ```
///
/// If used this way, you never need to interact with the store directly. To log
/// messages, you'll interact only with the SwiftLog APIs.
///
/// ```swift
/// let logger = Logger(label: "com.yourcompany.yourapp")
/// logger.info("This message will be stored persistently")
/// ```
///
/// But SwiftLog is not required and ``LoggerStore`` can also just as easily be used
/// directly. You can either create a custom store or use ``LoggerStore/shared`` one.
public final class LoggerStore: @unchecked Sendable {
    /// The URL the store was initialized with.
    public let storeURL: URL

    /// Returns `true` if the store was opened with a Pulse archive (a document
    /// with `.pulse` extension). The archives are readonly.
    public let isReadonly: Bool

    /// Returns the store info (only available for archives).
    public let info: Info?

    /// Returns the Core Data container associated with the store.
    public let container: NSPersistentContainer

    /// Returns the background managed object context used for all write operations.
    public let backgroundContext: NSManagedObjectContext

    private let document: PulseDocument

    // Deprecated in Pulse 2.0.
    @available(*, deprecated, message: "Renamed to `shared`")
    public static var `default`: LoggerStore { LoggerStore.shared }

    /// Re-transmits events processed by the store.
    public let events = PassthroughSubject<Event, Never>()

    private let options: Options
    private let configuration: Configuration
    private var isSaveScheduled = false
    private let queue = DispatchQueue(label: "com.github.kean.pulse.logger-store")

    // MARK: Shared

    /// Returns a shared store.
    ///
    /// You can replace the default store with a custom one. If you replace the
    /// shared store, it automatically gets registered as the default store
    /// for ``RemoteLogger`` and ``NetworkLoggerInsights``.
    public static var shared = LoggerStore.makeDefault() {
        didSet { register(store: shared) }
    }

    private static func register(store: LoggerStore) {
        if #available(iOS 14.0, tvOS 14.0, *) {
            RemoteLogger.shared.initialize(store: store)
        }
        NetworkLoggerInsights.shared.register(store: store)
    }

    private static func makeDefault() -> LoggerStore {
        let storeURL = URL.logs.appendingPathComponent("current.pulse", isDirectory: true)
        guard let store = try? LoggerStore(storeURL: storeURL, options: [.create, .sweep]) else {
            return LoggerStore(inMemoryStore: storeURL) // Right side should never happen
        }
        register(store: store)
        return store
    }

    // MARK: Configuration

    /// The store creation options.
    public struct Options: OptionSet, Sendable {
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

        /// Flushes entities to disk immediately and synchronously.
        ///
        /// - warning: When this option is enabled, all writes to the store
        /// happen immediately and synchronously.
        ///
        /// - note: This option can be used to ensure that if the app crashes,
        /// as much logs as possible are saved persistently. It can also be
        /// used to increase remote logging speed.
        public static let synchronous = Options(rawValue: 1 << 2)
    }

    /// The store configuration.
    public struct Configuration: @unchecked Sendable {
        /// Size limit in bytes. `64 Mb` by default. The limit is approximate.
        public var databaseSizeLimit: Int

        /// Size limit in bytes. `512 Mb` by default.
        public var blobsSizeLimit: Int

        /// Determines how often the messages are saved to the database. By default,
        /// 100 milliseconds - quickly enough, but avoiding too many individual writes.
        public var saveInterval: DispatchTimeInterval = .milliseconds(100)

        /// If `true`, the images added to the store as saved as small thumbnails.
        public var isStoringOnlyImageThumbnails = true

        /// For tesing purposes.
        var makeCurrentDate: () -> Date = { Date() }

        /// Gets called when the store receives an event. You can use it to
        /// modify the event before it is stored in order, for example, filter
        /// out some sensitive information. If you return `nil`, the event
        /// is ignored completely.
        public var willHandleEvent: @Sendable (Event) -> Event? = { $0 }

        /// Initializes the configuration.
        ///
        /// - parameters:
        ///   - databaseSizeLimit: The approximate limit of the database size. `64 Mb`
        ///   - blobsSizeLimit: The approximate limit of the blob storage that
        ///   contains network responses (HTTP body). `512 Mb` by default.
        public init(databaseSizeLimit: Int = 1048576 * 64, blobsSizeLimit: Int = 1048576 * 512) {
            self.databaseSizeLimit = databaseSizeLimit
            self.blobsSizeLimit = blobsSizeLimit
        }
    }

    // MARK: Initialization

    /// Initializes the store with the given URL.
    ///
    /// There are two types of URLs that the store supports:
    /// - A package (directory) with a Pulse database (optimized for writing)
    /// - A document (readonly, archive, optimized to storage and sharing)
    ///
    /// The ``LoggerStore/shared`` store is a package optimized for writing. When
    /// you are ready to share the store, create a Pulse document using `archive()`
    /// or `copy(to:)` methods. The document format is optimized to use the least
    /// amount of space possible.
    ///
    /// - parameters:
    ///   - storeURL: The store URL.
    ///   - options: By default, empty. To create a store, use ``Options/create``.
    ///   - configuration: The store configuration specifying size limit, etc.
    public convenience init(storeURL: URL, options: Options = [], configuration: Configuration = .init()) throws {
        var isDirectory: ObjCBool = ObjCBool(false)
        let fileExists = Files.fileExists(atPath: storeURL.path, isDirectory: &isDirectory)
        guard fileExists || options.contains(.create) else {
            throw LoggerStore.Error.fileDoesntExist
        }
        if !fileExists || isDirectory.boolValue { // Working with a package
            try self.init(packageURL: storeURL, create: !fileExists, options: options, configuration: configuration)
        } else { // Working with a zip archive
            try self.init(archiveURL: storeURL, options: options, configuration: configuration)
        }
    }

    init(packageURL: URL, create: Bool, options: Options, configuration: Configuration) throws {
        self.storeURL = packageURL
        self.options = options
        self.configuration = configuration

        if create {
            try Files.createDirectory(at: storeURL, withIntermediateDirectories: false, attributes: nil)
        }
        let databaseURL = storeURL.appendingPathComponent(databaseFileName, isDirectory: false)
        if !create {
            guard Files.fileExists(atPath: databaseURL.path) else {
                throw LoggerStore.Error.storeInvalid
            }
        }
        let blobsURL = storeURL.appendingPathComponent(blobsDirectoryName, isDirectory: true)
        if !Files.fileExists(atPath: blobsURL.path) {
            try Files.createDirectory(at: blobsURL, withIntermediateDirectories: false, attributes: nil)
        }

        self.container = LoggerStore.makeContainer(databaseURL: databaseURL, isViewing: false)
        try? LoggerStore.loadStore(container: container)
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.isReadonly = false
        self.info = nil
        self.document = .directory(blobs: BlobStore(path: blobsURL, sizeLimit: configuration.blobsSizeLimit))

        if options.contains(.sweep) {
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
                self?.sweep()
            }
        }
    }

    init(archiveURL: URL, options: Options, configuration: Configuration) throws {
        self.storeURL = archiveURL
        self.options = options
        self.configuration = configuration

        guard let archive = IndexedArchive(url: storeURL) else {
            throw LoggerStore.Error.storeInvalid
        }
        let manifest = try Info.make(archive: archive)
        let databaseURL = URL.temp.appendingPathComponent(manifest.id.uuidString, isDirectory: false)
        if !Files.fileExists(atPath: databaseURL.path) {
            guard let database = archive[databaseFileName] else {
                throw LoggerStore.Error.storeInvalid
            }
            try archive.extract(database, to: databaseURL)
        }

        self.container = LoggerStore.makeContainer(databaseURL: databaseURL, isViewing: true)
        try LoggerStore.loadStore(container: container)
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.isReadonly = true
        self.info = manifest
        self.document = .file(archive: archive, manifest: manifest)
    }

    init(inMemoryStore storeURL: URL) {
        self.storeURL = storeURL
        self.isReadonly = true
        self.container = NSPersistentContainer(name: "EmptyStore", managedObjectModel: Self.model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, _ in }
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.info = nil
        self.document = .empty
        self.options = []
        self.configuration = .init()
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
        var loadError: Swift.Error?
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
        handle(.messageStored(.init(
            createdAt: configuration.makeCurrentDate(),
            label: label,
            level: level,
            message: message,
            metadata: metadata?.unpack(),
            session: Session.current.id.uuidString,
            file: file,
            function: function,
            line: line
        )))
    }

    /// Stores the network request.
    ///
    /// - note: If you want to store incremental updates to the task, use
    /// `NetworkLogger` instead.
    public func storeRequest(_ request: URLRequest, response: URLResponse?, error: Error?, data: Data?, metrics: URLSessionTaskMetrics? = nil) {
        storeRequest(taskId: UUID(), taskType: .dataTask, request: request, response: response, error: error, data: data, metrics: metrics.map(NetworkLogger.Metrics.init))
    }
    
    func storeRequest(taskId: UUID, taskType: NetworkLogger.TaskType, request: URLRequest, response: URLResponse?, error: Error?, data: Data?, metrics: NetworkLogger.Metrics?) {
        handle(.networkTaskCompleted(.init(
            taskId: taskId,
            taskType: taskType,
            createdAt: configuration.makeCurrentDate(),
            originalRequest: NetworkLogger.Request(request),
            currentRequest: NetworkLogger.Request(request),
            response: response.map(NetworkLogger.Response.init),
            error: error.map(NetworkLogger.ResponseError.init),
            requestBody: request.httpBody ?? request.httpBodyStreamData(),
            responseBody: data,
            metrics: metrics,
            session: LoggerStore.Session.current.id.uuidString
        )))
    }

    /// Handles event created by the current store and dispatches it to observers.
    func handle(_ event: Event) {
        guard let event = configuration.willHandleEvent(event) else {
            return
        }
        perform {
            self._handle(event)
        }
        events.send(event)
    }

    /// Handles event emitted by the external store.
    func handleExternalEvent(_ event: Event) {
        perform { self._handle(event) }
    }

    private func _handle(_ event: Event) {
        switch event {
        case .messageStored(let event): process(event)
        case .networkTaskCreated(let event): process(event)
        case .networkTaskProgressUpdated(let event): process(event)
        case .networkTaskCompleted(let event): process(event)
        }
    }

    private func process(_ event: Event.MessageCreated) {
        let message = LoggerMessageEntity(context: backgroundContext)
        message.createdAt = event.createdAt
        message.level = event.level.rawValue
        message.levelOrder = event.level.order
        message.label = event.label
        message.session = event.session
        message.text = event.message
        if let metadata = event.metadata, !metadata.isEmpty {
            message.metadata = Set(metadata.map { key, value in
                let entity = LoggerMetadataEntity(context: backgroundContext)
                entity.key = key
                entity.value = value
                return entity
            })
        }
        message.file = event.file
        message.filename = (event.file as NSString).lastPathComponent
        message.function = event.function
        message.line = Int32(event.line)
    }

    private func process(_ event: Event.NetworkTaskCreated) {
        let request = findOrCreateNetworkRequestEntity(
            forTaskId: event.taskId,
            taskType: event.taskType,
            createdAt: event.createdAt,
            session: event.session
        )

        request.url = event.originalRequest.url?.absoluteString
        request.host = event.originalRequest.url?.host
        request.httpMethod = event.originalRequest.httpMethod
        request.requestState = LoggerNetworkRequestEntity.State.pending.rawValue

        request.details.originalRequest = try? JSONEncoder().encode(event.originalRequest)
        request.details.currentRequest = try? JSONEncoder().encode(event.currentRequest)

        if case let .directory(store) = document {
            request.requestBodyKey = store.storeData(event.requestBody)
        }
    }

    private func process(_ event: Event.NetworkTaskProgressUpdated) {
        guard let request = findNetworkRequestEntity(forTaskId: event.taskId) else { return }

        let progress = request.progress ?? {
            let progress = LoggerNetworkRequestProgressEntity(context: backgroundContext)
            request.progress = progress
            return progress
        }()

        progress.completedUnitCount = event.completedUnitCount
        progress.totalUnitCount = event.totalUnitCount
    }

    private func process(_ event: Event.NetworkTaskCompleted) {
        let request = findOrCreateNetworkRequestEntity(
            forTaskId: event.taskId,
            taskType: event.taskType,
            createdAt: event.createdAt,
            session: event.session
        )

        // Populate remaining request fields
        request.url = event.originalRequest.url?.absoluteString
        request.host = event.originalRequest.url?.host
        request.httpMethod = event.originalRequest.httpMethod
        request.errorDomain = event.error?.domain
        request.errorCode = Int32(event.error?.code ?? 0)
        let statusCode = Int32(event.response?.statusCode ?? 0)
        request.statusCode = statusCode
        request.startDate = event.metrics?.taskInterval.start
        request.duration = event.metrics?.taskInterval.duration ?? 0
        request.contentType = event.response?.headers["Content-Type"]
        let isFailure = event.error != nil || (statusCode != 0 && !(200..<400).contains(statusCode))
        request.requestState = (isFailure ? LoggerNetworkRequestEntity.State.failure : .success).rawValue
        request.redirectCount = Int16(event.metrics?.redirectCount ?? 0)

        // Populate response/request data
        let contentType = event.response?.headers["Content-Type"].flatMap(NetworkLogger.ContentType.init)
        if case let .directory(store) = document {
            request.requestBodyKey = store.storeData(event.requestBody)
            if let responseBody = event.responseBody {
                request.responseBodyKey = store.storeData(preprocessData(responseBody, contentType: contentType))
            }
        }

        switch event.taskType {
        case .dataTask:
            request.responseBodySize = Int64(event.responseBody?.count ?? 0)
        case .downloadTask:
            request.responseBodySize = event.metrics?.transactions.last(where: {
                $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue
            })?.details?.countOfResponseBodyBytesReceived ?? request.progress?.completedUnitCount ?? -1
        case .uploadTask:
            request.requestBodySize = event.metrics?.transactions.last(where: {
                $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue
            })?.details?.countOfRequestBodyBytesSent ?? Int64(event.requestBody?.count ?? -1)
        default:
            break
        }

        let transactions = event.metrics?.transactions ?? []
        request.isFromCache = transactions.last?.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.localCache.rawValue || (transactions.last?.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue && transactions.last?.response?.statusCode == 304)

        // Populate details
        let details = request.details
        let encoder = JSONEncoder()
        details.originalRequest = try? encoder.encode(event.originalRequest)
        details.currentRequest = try? encoder.encode(event.currentRequest)
        details.response = try? encoder.encode(event.response)
        details.error = try? encoder.encode(event.error)
        details.metrics = try? encoder.encode(event.metrics)
        if let responseBody = event.responseBody, (contentType?.isImage ?? false),
           let metadata = makeImageMetadata(from: responseBody) {
            details.metadata = try? encoder.encode(metadata)
        }

        // Completed
        if let progress = request.progress {
            backgroundContext.delete(progress)
            request.progress = nil
        }

        // Update associated message state
        if let message = request.message { // Should always be non-nill
            message.requestState = request.requestState
            message.text = event.originalRequest.url?.absoluteString ?? "–"
            if isFailure {
                let level = Level.error
                message.level = level.rawValue
                message.levelOrder = level.order
            }
        }
    }

    private func preprocessData(_ data: Data, contentType: NetworkLogger.ContentType?) -> Data {
        guard data.count > 5000 else { // 5 KB is ok
            return data
        }
        guard configuration.isStoringOnlyImageThumbnails && (contentType?.isImage ?? false) else {
            return data
        }
        guard let thumbnail = Graphics.makeThumbnail(from: data, targetSize: 256),
              let data = Graphics.encode(thumbnail) else {
            return data
        }
        return data
    }

    private func makeImageMetadata(from data: Data) -> [String: String]? {
        guard let image = PlatformImage(data: data) else {
            return nil
        }
        return [
            "ResponsePixelWidth": String(Int(image.size.width)),
            "ResponsePixelHeight": String(Int(image.size.height))
        ]
    }

    private func findNetworkRequestEntity(forTaskId taskId: UUID) -> LoggerNetworkRequestEntity? {
        let entity = NSFetchRequest<LoggerNetworkRequestEntity>(entityName: "\(LoggerNetworkRequestEntity.self)")
        entity.fetchLimit = 1
        entity.predicate = NSPredicate(format: "taskId == %@", taskId as NSUUID)
        return try? backgroundContext.fetch(entity).first
    }

    private func findOrCreateNetworkRequestEntity(forTaskId taskId: UUID, taskType: NetworkLogger.TaskType, createdAt: Date, session: String) -> LoggerNetworkRequestEntity {
        if let entity = findNetworkRequestEntity(forTaskId: taskId) {
            return entity
        }

        let request = LoggerNetworkRequestEntity(context: backgroundContext)
        request.taskId = taskId
        request.rawTaskType = taskType.rawValue
        request.createdAt = createdAt
        request.responseBodySize = -1
        request.requestBodySize = -1
        request.isFromCache = false
        request.details = LoggerNetworkRequestDetailsEntity(context: backgroundContext)
        request.session = session

        let message = LoggerMessageEntity(context: backgroundContext)
        message.createdAt = createdAt
        message.level = Level.debug.rawValue
        message.levelOrder = Level.debug.order
        message.label = "network"
        message.session = session
        message.file = ""
        message.filename = ""
        message.function = ""
        message.line = 0
        message.requestState = LoggerNetworkRequestEntity.State.pending.rawValue

        message.request = request
        request.message = message

        return request
    }

    private func setNeedsSave() {
        guard !isSaveScheduled else { return }
        isSaveScheduled = true
        queue.asyncAfter(deadline: .now() + configuration.saveInterval) { [weak self] in
            self?.flush()
        }
    }

    private func flush() {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }
            if self.isSaveScheduled, Files.fileExists(atPath: self.storeURL.path) {
                try? self.backgroundContext.save()
                self.isSaveScheduled = false
            }
        }
    }

    // MARK: Direct Modifiction

    private func perform(_ changes: @escaping () -> Void) {
        guard !isReadonly else { return }

        if options.contains(.synchronous) {
            backgroundContext.performAndWait {
                changes()
                try? backgroundContext.save()
            }

        } else {
            backgroundContext.perform {
                changes()
                self.setNeedsSave()
            }
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

    private enum PulseDocument: Sendable {
        case directory(blobs: BlobStore)
        case file(archive: IndexedArchive, manifest: Info)
        case empty
    }
}

extension LoggerStore {
    public enum MetadataValue {
        case string(String)
        case stringConvertible(CustomStringConvertible)
    }

    public typealias Metadata = [String: MetadataValue]

    // Compatible with SwiftLog.Logger.Level
    @frozen public enum Level: String, CaseIterable, Codable, Hashable, Sendable {
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
        perform { self._removeAll() }
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
    public func copy(to targetURL: URL) throws -> Info {
        switch document {
        case .directory(let blobs):
            var result: Result<Info, Swift.Error>?
            backgroundContext.performAndWait {
                result = Result { try copy(to: targetURL, blobs: blobs) }
            }
            return try (result ?? .failure(Error.unknownError)).get()
        case .file(_, let manifest):
            try Files.copyItem(at: storeURL, to: targetURL)
            return manifest
        case .empty:
            throw LoggerStore.Error.storeInvalid
        }
    }

    private func copy(to targetURL: URL, blobs: BlobStore) throws -> Info {
        let tempURL = URL.temp.appendingPathComponent(UUID().uuidString, isDirectory: true)
        Files.createDirectoryIfNeeded(at: tempURL)
        do {
            return try copy(to: targetURL, tempURL: tempURL, blobs: blobs)
        } catch {
            try? Files.removeItem(at: tempURL)
            throw error
        }
    }

    private func copy(to targetURL: URL, tempURL: URL, blobs: BlobStore) throws -> Info {
        // Create copy of the store
        let databaseURL = tempURL.appendingPathComponent(databaseFileName, isDirectory: false)
        try container.persistentStoreCoordinator.createCopyOfStore(at: databaseURL)

        // Create copy of the blobs
        let blobsURL = tempURL.appendingPathComponent(blobsDirectoryName, isDirectory: true)
        try blobs.copyContents(to: blobsURL)

        // Create description
        let databaseAttributes = try Files.attributesOfItem(atPath: databaseURL.path)
        let currentDatabaseAttributes = try Files.attributesOfItem(atPath: storeURL.appendingPathComponent(databaseFileName).path)
        let manifest = Info(
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
        try backgroundContext.fetch(LoggerMessageEntity.fetchRequest()).count
    }

    private func networkRequestsCount() throws -> Int {
        try backgroundContext.fetch(LoggerNetworkRequestEntity.fetchRequest()).count
    }
}

// MARK: - LoggerStore (Sweep)

extension LoggerStore {
    func sweep() {
        backgroundContext.perform { try? self._sweep() }
    }

    private func _sweep() throws {
        let attributes = try Files.attributesOfItem(atPath: storeURL.appendingPathComponent(databaseFileName, isDirectory: false).path)
        let size = attributes[.size] as? Int64 ?? 0

        guard size > configuration.databaseSizeLimit else {
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

private let currentStoreVersion = "2.0.0"
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

extension LoggerStore {
    public enum Error: Swift.Error, LocalizedError {
        case fileDoesntExist
        case storeInvalid
        case unsupportedVersion
        case documentIsReadonly
        case unknownError

        public var errorDescription: String? {
            switch self {
            case .fileDoesntExist: return "File doesn't exist"
            case .storeInvalid: return "Store format is invalid"
            case .documentIsReadonly: return "Document is readonly"
            case .unsupportedVersion: return "The store was created by one of the earlier versions of Pulse and is no longer supported"
            case .unknownError: return "Unexpected error"
            }
        }
    }
}
