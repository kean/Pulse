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
    public let isArchive: Bool

    /// Returns the Core Data container associated with the store.
    public let container: NSPersistentContainer

    /// Returns the view context for accessing entities on the main thead.
    public var viewContext: NSManagedObjectContext { container.viewContext }

    /// Returns the background managed object context used for all write operations.
    public let backgroundContext: NSManagedObjectContext

    // Deprecated in Pulse 2.0.
    @available(*, deprecated, message: "Renamed to `shared`")
    public static var `default`: LoggerStore { LoggerStore.shared }

    /// Re-transmits events processed by the store.
    public let events = PassthroughSubject<Event, Never>()

    /// In case of a temporary store, contains URL to the database open for writing.
    private let writableStoreURL: URL
    private let options: Options
    private let configuration: Configuration
    private let document: PulseDocument
    private var isSaveScheduled = false
    private let queue = DispatchQueue(label: "com.github.kean.pulse.logger-store")
    private var manifest: Manifest {
        didSet { try? save(manifest) }
    }

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
        let manifestURL = storeURL.appendingPathComponent(manifestFileName, isDirectory: false)

        if !create {
            guard Files.fileExists(atPath: databaseURL.path) else {
                throw LoggerStore.Error.storeInvalid
            }
        }

        // Read the store version and perform migration if needed
        var manifest = try LoggerStore.readOrCreateManifest(at: manifestURL)
        if !manifest.isCurrentVersion {
            // The safest option is to simply remove old data on all version updates
            // and not even attempt to be any potetially slow and error-pront migration.
            let blobsURL = storeURL.appendingPathComponent("blobs", isDirectory: true)
            try? Files.removeItem(at: blobsURL) // Blobs were previously stored in a filesystem
            try? Files.removeItem(at: databaseURL)
            // Update info with the latest version
            manifest.version = Manifest.currentVersion
        }
        self.manifest = manifest
        self.writableStoreURL = packageURL

        self.container = LoggerStore.makeContainer(databaseURL: databaseURL, isViewing: false)
        try? LoggerStore.loadStore(container: container)
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.isArchive = false
        self.document = .package
        self.viewContext.userInfo[Pins.pinServiceKey] = Pins(store: self)
        try save(manifest)

        if isAutomaticSweepNeeded {
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(15)) { [weak self] in
                self?.sweep()
            }
        }
    }

    init(archiveURL: URL, options: Options, configuration: Configuration) throws {
        self.storeURL = archiveURL
        self.options = options
        self.configuration = configuration

        guard let archive = Archive(url: storeURL, accessMode: .read) else {
            throw LoggerStore.Error.storeInvalid
        }
        let manifest = try Manifest.make(archive: archive)
        guard manifest.version >= Version(2, 0, 0) else {
            throw LoggerStore.Error.unsupportedVersion
        }
        let tempStoreURL = URL.temp.appendingPathComponent(manifest.storeId.uuidString, isDirectory: false)
        if !Files.fileExists(atPath: tempStoreURL.path) {
            try Files.unzipItem(at: archiveURL, to: tempStoreURL)
        }

        self.manifest = manifest
        self.writableStoreURL = tempStoreURL

        let databaseURL = tempStoreURL.appendingPathComponent(databaseFileName, isDirectory: false)
        self.container = LoggerStore.makeContainer(databaseURL: databaseURL, isViewing: true)
        try LoggerStore.loadStore(container: container)
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.isArchive = true
        self.manifest = manifest
        self.document = .file
        self.viewContext.userInfo[Pins.pinServiceKey] = Pins(store: self)
        try save(manifest)
    }

    private static func readOrCreateManifest(at url: URL) throws -> Manifest {
        if let data = try? Data(contentsOf: url) {
            return try JSONDecoder().decode(Manifest.self, from: data)
        }
        // Only stores prior to 2.0.0 had no manifest.
        // If it's a new store, it'll also go through this step.
        return Manifest(storeId: UUID(), version: Version(1, 0, 0))
    }

    init(inMemoryStore storeURL: URL) {
        self.storeURL = storeURL
        self.writableStoreURL = storeURL
        self.isArchive = true
        self.container = NSPersistentContainer(name: "EmptyStore", managedObjectModel: Self.model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, _ in }
        self.backgroundContext = LoggerStore.makeBackgroundContext(for: container)
        self.manifest = .init(storeId: UUID(), version: .init(1, 0, 0   ))
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
        container.viewContext.undoManager = nil
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
    public func storeMessage(label: String, level: Level, message: String, metadata: [String: MetadataValue]? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
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
        handle(.networkTaskCompleted(.init(
            taskId: UUID(),
            taskType: .dataTask,
            createdAt: configuration.makeCurrentDate(),
            originalRequest: NetworkLogger.Request(request),
            currentRequest: NetworkLogger.Request(request),
            response: response.map(NetworkLogger.Response.init),
            error: error.map(NetworkLogger.ResponseError.init),
            requestBody: request.httpBody ?? request.httpBodyStreamData(),
            responseBody: data,
            metrics: metrics.map(NetworkLogger.Metrics.init),
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

        if let requestBody = event.requestBody {
            let contentType = event.originalRequest.headers["Content-Type"].flatMap(NetworkLogger.ContentType.init)
            request.requestBody = storeBlob(preprocessData(requestBody, contentType: contentType))
        }
        if let responseData = event.responseBody {
            request.responseBody = storeBlob(preprocessData(responseData, contentType: contentType))
        }

        switch event.taskType {
        case .dataTask:
            request.requestBodySize = Int64(event.requestBody?.count ?? 0)
            request.responseBodySize = Int64(event.responseBody?.count ?? 0)
        case .downloadTask:
            request.responseBodySize = event.metrics?.transactions.last(where: {
                $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue
            })?.transferSize.responseBodyBytesReceived ?? request.progress?.completedUnitCount ?? -1
        case .uploadTask:
            request.requestBodySize = event.metrics?.transactions.last(where: {
                $0.resourceFetchType == URLSessionTaskMetrics.ResourceFetchType.networkLoad.rawValue
            })?.transferSize.requestBodyBytesSent ?? Int64(event.requestBody?.count ?? -1)
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
        try? backgroundContext.first(LoggerNetworkRequestEntity.self) {
            $0.predicate = NSPredicate(format: "taskId == %@", taskId as NSUUID)
        }
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

    private func storeBlob(_ data: Data) -> LoggerBlobHandleEntity? {
        guard !data.isEmpty else {
            return nil
        }
        let key = data.sha256
        let existingEntity = try? backgroundContext.first(LoggerBlobHandleEntity.self) {
            $0.predicate = NSPredicate(format: "key == %@", key)
        }
        if let entity = existingEntity {
            entity.linkCount += 1
            return entity
        }
        let entity = LoggerBlobHandleEntity(context: backgroundContext)
        entity.key = key
        entity.linkCount = 1
        entity.data = data
        entity.size = Int64(data.count)
        return entity
    }

    private func unlink(_ blob: LoggerBlobHandleEntity) {
        blob.linkCount -= 1
        if blob.linkCount == 0 {
            backgroundContext.delete(blob)
        }
    }

    // MARK: - Performing Changes

    private func perform(_ changes: @escaping () -> Void) {
        guard !isArchive else { return }

        if options.contains(.synchronous) {
            backgroundContext.performAndWait {
                changes()
                self.saveAndReset()
            }
        } else {
            backgroundContext.perform {
                changes()
                self.setNeedsSave()
            }
        }
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
                self.saveAndReset()
                self.isSaveScheduled = false
            }
        }
    }

    private func saveAndReset() {
        try? backgroundContext.save()
        backgroundContext.reset()
    }
}

// MARK: - LoggerStore (Accessing Messages)

extension LoggerStore {
    /// Returns all recorded messages, least recent messages come first.
    public func allMessages() throws -> [LoggerMessageEntity] {
        try viewContext.fetch(LoggerMessageEntity.self, sortedBy: \.createdAt)
    }

    /// Returns all recorded network requests, least recent messages come first.
    public func allNetworkRequests() throws -> [LoggerNetworkRequestEntity] {
        try viewContext.fetch(LoggerNetworkRequestEntity.self, sortedBy: \.createdAt)
    }

    /// Removes all of the previously recorded messages.
    public func removeAll() {
        perform { self._removeAll() }
    }

    private func _removeAll() {
        switch document {
        case .package:
            try? deleteEntities(for: LoggerMessageEntity.fetchRequest())
            try? deleteEntities(for: LoggerBlobHandleEntity.fetchRequest())
        case .file, .empty:
            break // Do nothing, readonly
        }
    }
}

// MARK: - LoggerStore (Copy)

extension LoggerStore {
    #warning("TODO: make async")

    /// Creates a copy of the current store at the given URL. The created copy
    /// has `.pulse` extension (actually a `.zip` archive).
    ///
    /// The destination directory must already exist. But if the file at the
    /// destination URL already exists, throws an error.
    ///
    /// Thread-safe. But must not be called inside the `backgroundContext` queue.
    public func copy(to targetURL: URL) throws {
        switch document {
        case .package:
            var result: Result<Void, Swift.Error>?
            backgroundContext.performAndWait {
                result = Result { try _copy(to: targetURL) }
            }
            return try (result ?? .failure(Error.unknownError)).get()
        case .file:
            try Files.copyItem(at: storeURL, to: targetURL)
        case .empty:
            throw LoggerStore.Error.storeInvalid
        }
    }

    private func _copy(to targetURL: URL) throws {
        let tempURL = URL.temp.appendingPathComponent(UUID().uuidString, isDirectory: true)
        Files.createDirectoryIfNeeded(at: tempURL)
        do {
            try _copy(to: targetURL, tempURL: tempURL)
        } catch {
            try? Files.removeItem(at: tempURL)
            throw error
        }
    }

    private func _copy(to targetURL: URL, tempURL: URL) throws {
        // Create copy of the store
        let databaseURL = tempURL.appendingPathComponent(databaseFileName, isDirectory: false)
        try container.persistentStoreCoordinator.createCopyOfStore(at: databaseURL)

        // Create description
        let manifestURL = tempURL.appendingPathComponent(manifestFileName, isDirectory: false)
        var manifest = manifest
        manifest.storeId = UUID()
        try JSONEncoder().encode(manifest).write(to: manifestURL)

        // Archive and add .pulse extension
        try Files.zipItem(at: tempURL, to: targetURL, shouldKeepParent: false, compressionMethod: .deflate)
    }
}

// MARK: - LoggerStore (Sweep)

extension LoggerStore {

    var isAutomaticSweepNeeded: Bool {
        guard options.contains(.sweep) else { return false }
        guard let lastSweepDate = manifest.lastSweepDate else {
            manifest.lastSweepDate = Date() // No need to run it right away
            return false
        }
        return Date().timeIntervalSince(lastSweepDate) > configuration.sweepInterval
    }

    func sweep() {
        backgroundContext.perform { try? self._sweep() }
        manifest.lastSweepDate = Date()
    }

    func syncSweep() {
        backgroundContext.performAndWait { try? self._sweep() }
    }

    private func _sweep() throws {
        try? removeExpiredMessages()
        try? reduceDatabaseSize()
        try? reduceBlobStoreSize()

        if backgroundContext.hasChanges {
            saveAndReset()
        }
    }

    private func removeExpiredMessages() throws {
        let cutoffDate = configuration.makeCurrentDate().addingTimeInterval(-configuration.maxAge)
        try removeMessage(before: cutoffDate)
    }

    private func reduceDatabaseSize() throws {
        let attributes = try Files.attributesOfItem(atPath: storeURL.appendingPathComponent(databaseFileName, isDirectory: false).path)
        let size = attributes[.size] as? Int64 ?? 0

        guard size > configuration.databaseSizeLimit else {
            return // All good, no need to perform any work.
        }

        let messages = try backgroundContext.fetch(LoggerMessageEntity.self, sortedBy: \.createdAt, ascending: false)
        let count = messages.count
        guard count > 10 else { return } // Sanity check

        let cutoffDate = messages[Int(Double(count) * configuration.trimRatio)].createdAt
        try removeMessage(before: cutoffDate)
    }

    private func removeMessage(before date: Date) throws {
        // Unlink blobs associated with the requests the store is about to remove
        let requests = try backgroundContext.fetch(LoggerNetworkRequestEntity.self) {
            $0.predicate = NSPredicate(format: "createdAt < %@ AND (requestBody != NULL OR responseBody != NULL)", date as NSDate)
        }
        for request in requests {
            request.requestBody.map(unlink)
            request.responseBody.map(unlink)
        }

        // Remove messages using an efficient batch request
        let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LoggerMessageEntity")
        deleteRequest.predicate = NSPredicate(format: "createdAt < %@", date as NSDate)
        try deleteEntities(for: deleteRequest)
    }

    private func reduceBlobStoreSize() throws {
        var currentSize = try getBlobsSize()
        guard currentSize > configuration.blobsSizeLimit else {
            return // All good, no need to remove anything
        }
        let requests = try backgroundContext.fetch(LoggerNetworkRequestEntity.self, sortedBy: \.createdAt) {
            $0.predicate = NSPredicate(format: "requestBody != NULL OR responseBody != NULL")
        }
        let targetSize = Int(Double(configuration.blobsSizeLimit) * configuration.trimRatio)
        func _unlink(_ blob: LoggerBlobHandleEntity) {
            unlink(blob)
            currentSize -= blob.size
        }
        for request in requests where currentSize > targetSize {
            if let requestBody = request.requestBody {
                _unlink(requestBody)
                request.requestBody = nil
            }
            if let responseBody = request.responseBody {
                _unlink(responseBody)
                request.responseBody = nil
            }
        }
    }

    private func getBlobsSize() throws -> Int64 {
        let request = LoggerBlobHandleEntity.fetchRequest()

        let description = NSExpressionDescription()
        description.name = "sum"

        let keypathExp1 = NSExpression(forKeyPath: "size")
        let expression = NSExpression(forFunction: "sum:", arguments: [keypathExp1])
        description.expression = expression
        description.expressionResultType = .integer64AttributeType

        request.returnsObjectsAsFaults = true
        request.propertiesToFetch = [description]
        request.resultType = .dictionaryResultType

        let result = try backgroundContext.fetch(request) as? [[String: Any]]
        return (result?.first?[description.name] as? Int64) ?? 0
    }
}

// MARK: - LoggerStore (Info)

#warning("TODO: save info for archive & add test")

extension LoggerStore {
    /// Returns info about the current store.
    public var info: Info {
        get async throws {
            try await withUnsafeThrowingContinuation { continuation in
                do {
                    let info = try getInfo()
                    continuation.resume(with: .success(info))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
        }
    }

    private func getInfo() throws -> Info {
        if isArchive {
            guard let info = Info.make(storeURL: storeURL) else {
                throw LoggerStore.Error.storeInvalid
            }
            return info
        }

        let databasURL = storeURL.appendingPathComponent(databaseFileName, isDirectory: false)
        let databaseAttributes = try Files.attributesOfItem(atPath: databasURL.path)

        let messageCount = try backgroundContext.count(for: LoggerMessageEntity.self)
        let requestCount = try backgroundContext.count(for: LoggerNetworkRequestEntity.self)
        let blobCount = try backgroundContext.count(for: LoggerBlobHandleEntity.self)

        return Info(
            storeId: manifest.storeId,
            storeVersion: manifest.version.description,
            createdDate: (databaseAttributes[.creationDate] as? Date) ?? Date(),
            modifiedDate: (databaseAttributes[.modificationDate] as? Date) ?? Date(),
            archivedDate: nil,
            messageCount: messageCount - requestCount,
            requestCount: requestCount,
            blobCount: blobCount,
            totalStoreSize: try storeURL.directoryTotalAllocatedSize(),
            blobsSize: try getBlobsSize(),
            appInfo: .make(),
            deviceInfo: .make()
        )
    }
}

// MARK: - LoggerStore (Pins)

extension LoggerStore {
    public var pins: Pins { Pins(store: self) }

    public final class Pins {
        static let pinServiceKey = "com.github.kean.pulse.pin-service"

        weak var store: LoggerStore?

        public init(store: LoggerStore) {
            self.store = store
        }

        public func togglePin(for message: LoggerMessageEntity) {
            guard let store = store else { return }
            store.perform {
                guard let message = store.backgroundContext.object(with: message.objectID) as? LoggerMessageEntity else { return }
                self._togglePin(for: message)
            }
        }

        public func togglePin(for request: LoggerNetworkRequestEntity) {
            guard let store = store else { return }
            store.perform {
                guard let request = store.backgroundContext.object(with: request.objectID) as? LoggerNetworkRequestEntity else { return }
                request.message.map(self._togglePin)
            }
        }

        public func removeAllPins() {
            guard let store = store else { return }
            store.perform {
                let messages = try? store.backgroundContext.fetch(LoggerMessageEntity.self) {
                    $0.predicate = NSPredicate(format: "isPinned == YES")
                }
                for message in messages ?? [] {
                    self._togglePin(for: message)
                }
            }
        }

        private func _togglePin(for message: LoggerMessageEntity) {
            message.isPinned.toggle()
            message.request?.isPinned.toggle()
        }
    }
}

// MARK: - LoggerStore (Private)

extension LoggerStore {
    private func deleteEntities(for fetchRequest: NSFetchRequest<NSFetchRequestResult>) throws {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs

        let result = try backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
        guard let ids = result?.result as? [NSManagedObjectID] else { return }

        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [backgroundContext])

        viewContext.perform {
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [self.viewContext])
        }
    }

    private func save(_ manifest: Manifest) throws {
        let manifestURL = writableStoreURL.appendingPathComponent(manifestFileName, isDirectory: false)
        try JSONEncoder().encode(manifest).write(to: manifestURL)
    }
}

// MARK: - LoggerStore (Error)

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

// MARK: - LoggerStore (Manifest)

extension LoggerStore {
    private struct Manifest: Codable {
        var storeId: UUID
        var version: Version
        var lastSweepDate: Date?

        var isCurrentVersion: Bool {
            version == Manifest.currentVersion
        }

        static let currentVersion = Version(2, 0, 0)

        static func make(archive: Archive) throws -> Manifest {
            guard let manifest = archive[manifestFileName],
                  let data = archive.getData(for: manifest) else {
                throw NSError(domain: NSErrorDomain() as String, code: NSURLErrorResourceUnavailable, userInfo: [NSLocalizedDescriptionKey: "Store manifest is missing"])
            }
            return try JSONDecoder().decode(Manifest.self, from: data)
        }
    }
}

// MARK: - Constants

let manifestFileName = "manifest.json"
let databaseFileName = "logs.sqlite"
let infoFilename = "info.json"

private enum PulseDocument: Sendable {
    case package
    case file
    case empty
}
