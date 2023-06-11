// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Combine

/// Persistently stores logs, network requests, and response blobs.
///
/// But SwiftLog is not required and ``LoggerStore`` can also just as easily be used
/// directly. You can either create a custom store or use ``LoggerStore/shared`` one.
public final class LoggerStore: @unchecked Sendable, Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }

    /// The URL the store was initialized with.
    public let storeURL: URL

    /// Returns `true` if the store was opened with a Pulse archive (a document
    /// with `.pulse` extension). The archives are readonly.
    public let isArchive: Bool

    /// The options with which the store was opened with.
    public let options: Options

    /// The configuration with which the store was initialized with.
    public let configuration: Configuration

    /// Current session or the latest session in case of an archive.
    private(set) public var session: Session = .current

    /// Returns the Core Data container associated with the store.
    public let container: NSPersistentContainer

    /// Returns the view context for accessing entities on the main thread.
    public var viewContext: NSManagedObjectContext { container.viewContext }

    /// Returns the background managed object context used for all write operations.
    public let backgroundContext: NSManagedObjectContext

    /// Re-transmits events processed by the store.
    public let events = PassthroughSubject<Event, Never>()

    /// The store version.
    public var version: String { manifest.version.description }

    private let document: PulseDocumentType
    private var isSaveScheduled = false
    private let queue = DispatchQueue(label: "com.github.kean.pulse.logger-store")
    private var manifest: Manifest {
        didSet { try? save(manifest) }
    }
    private var sessionIndex: Int64 = 0

    /// The folder where Pulse stores its documents.
    public static var logsURL: URL { URL.logs }

    private let blobsURL: URL
    private let manifestURL: URL
    private let databaseURL: URL // Points to a temporary location if archive

    private var requestsCache: [NetworkLogger.Request: NetworkRequestEntity] = [:]
    private var responsesCache: [NetworkLogger.Response: NetworkResponseEntity] = [:]

    // MARK: Shared

    /// Returns a shared store.
    ///
    /// You can replace the default store with a custom one. If you replace the
    /// shared store, it automatically gets registered as the default store
    /// for ``RemoteLogger``.
    public static var shared = LoggerStore.makeDefault() {
        didSet { register(store: shared) }
    }

    private static func register(store: LoggerStore) {
        guard Thread.isMainThread else {
            return DispatchQueue.main.async { register(store: store) }
        }
        if RemoteLogger.shared.store == nil {
            RemoteLogger.shared.initialize(store: store)
        }
    }

    private static func makeDefault() -> LoggerStore {
        let storeURL = URL.logs.appending(directory: "current.pulse")
        guard let store = try? LoggerStore(storeURL: storeURL, options: [.create, .sweep]) else {
            return LoggerStore(inMemoryStore: storeURL) // Should never happen
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
    /// you are ready to share the store, create a Pulse document using ``copy(to:predicate:)`` method. The document format is optimized to use the least
    /// amount of space possible.
    ///
    /// - parameters:
    ///   - storeURL: The store URL.
    ///   - options: By default, empty. To create a store, use ``Options-swift.struct/create``.
    ///   - configuration: The store configuration specifying size limit, etc.
    public init(storeURL: URL, options: Options = [], configuration: Configuration = .init()) throws {
        var isDirectory: ObjCBool = ObjCBool(false)
        let fileExists = Files.fileExists(atPath: storeURL.path, isDirectory: &isDirectory)
        guard fileExists || options.contains(.create) else {
            throw LoggerStore.Error.fileDoesntExist
        }
        self.isArchive = fileExists && !isDirectory.boolValue
        self.storeURL = storeURL
        self.blobsURL = storeURL.appending(directory: blobsDirectoryName)
        self.manifestURL = storeURL.appending(filename: manifestFilename)
        self.options = options
        self.configuration = configuration

        if !isArchive {
            self.databaseURL = storeURL.appending(filename: databaseFilename)
            if options.contains(.create) {
                if !Files.fileExists(atPath: storeURL.path) {
                    try Files.createDirectory(at: storeURL, withIntermediateDirectories: false)
                }
                Files.createDirectoryIfNeeded(at: blobsURL)
            } else {
                guard Files.fileExists(atPath: databaseURL.path) else {
                    throw LoggerStore.Error.storeInvalid
                }
            }
            if var manifest = Manifest(url: manifestURL) {
                if manifest.version != .currentStoreVersion {
                    // Upgrading to a new version of Pulse store
                    try? LoggerStore.removePreviousStore(at: storeURL)
                    manifest.version = .currentStoreVersion // Update version, but keep the storeId
                }
                self.manifest = manifest
            } else {
                if Files.fileExists(atPath: databaseURL.path) {
                    // Updating from Pulse 1.0 that didn't have a manifest file
                    try? LoggerStore.removePreviousStore(at: storeURL)
                }
                self.manifest = Manifest(storeId: UUID(), version: .currentStoreVersion)
            }
            self.document = .package
        } else {
            let document = try PulseDocument(documentURL: storeURL)
            let info = try document.open()
            guard try Version(string: info.storeVersion) >= .minimumSupportedVersion else {
                throw LoggerStore.Error.unsupportedVersion(version: info.storeVersion, minimumSupportedVersion: Version.minimumSupportedVersion.description)
            }
            // Extract and decompress _only_ the database. The blobs can be read
            // directly from the compressed archive on demand.
            self.databaseURL = URL.temp.appending(filename: info.storeId.uuidString)
            if !Files.fileExists(atPath: databaseURL.path) {
                try document.database().decompressed().write(to: databaseURL)
            }
            self.document = .archive(info, document)
            self.manifest = .init(storeId: info.storeId, version: try Version(string: info.storeVersion))
        }

        self.container = LoggerStore.makeContainer(databaseURL: databaseURL)
        try container.loadStore()
        self.backgroundContext = container.newBackgroundContext()

        try postInitialization()
    }

    // When migrating to a new version of the store, the most reliable and safest
    // option is to remove the previous data which is acceptable for logs.
    private static func removePreviousStore(at storeURL: URL) throws {
        try Files.removeItem(at: storeURL)
        try Files.createDirectory(at: storeURL, withIntermediateDirectories: true)
    }

    private func postInitialization() throws {
        backgroundContext.performAndWait { [context = backgroundContext] in
            context.userInfo[WeakLoggerStore.loggerStoreKey] = WeakLoggerStore(store: self)
        }

        if options.contains(.create) && !options.contains(.readonly) && configuration.isAutoStartingSession {
            perform { _ in
                self.saveEntity(for: self.session, info: .make())
            }
        } else {
            viewContext.performAndWait {
                let latestSession = try? self.viewContext.first(LoggerSessionEntity.self) {
                    $0.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerSessionEntity.createdAt, ascending: false)]
                }
                if let session = latestSession, manifest.version > Version(3, 3, 0) {
                    self.session = .init(id: session.id, startDate: session.createdAt)
                }
            }
        }

        if Thread.isMainThread {
            self.viewContext.userInfo[Pins.pinServiceKey] = Pins(store: self)
            self.viewContext.userInfo[WeakLoggerStore.loggerStoreKey] = WeakLoggerStore(store: self)
        } else {
            viewContext.performAndWait {
                self.viewContext.userInfo[Pins.pinServiceKey] = Pins(store: self)
                self.viewContext.userInfo[WeakLoggerStore.loggerStoreKey] = WeakLoggerStore(store: self)
            }
        }

        if !isArchive && !options.contains(.readonly) {
            try save(manifest)
            if isAutomaticSweepNeeded {
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
                    self?.sweep()
                }
            }
        }
    }

    /// Creates a new background context.
    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.performAndWait {
            context.userInfo[WeakLoggerStore.loggerStoreKey] = WeakLoggerStore(store: self)
        }
        return context
    }

    /// This is a safe fallback for the initialization of the shared store.
    init(inMemoryStore storeURL: URL) {
        self.storeURL = storeURL
        self.blobsURL = storeURL.appending(directory: blobsDirectoryName)
        self.manifestURL = storeURL.appending(directory: manifestFilename)
        self.databaseURL = storeURL.appending(directory: databaseFilename)
        self.isArchive = true
        self.container = .inMemoryReadonlyContainer
        self.backgroundContext = container.newBackgroundContext()
        self.manifest = .init(storeId: UUID(), version: .currentStoreVersion)
        self.document = .package
        self.options = []
        self.configuration = .init()
    }

    private static func makeContainer(databaseURL: URL) -> NSPersistentContainer {
        let container = NSPersistentContainer(name: databaseURL.lastPathComponent, managedObjectModel: Self.model)
        let store = NSPersistentStoreDescription(url: databaseURL)
        store.setValue("DELETE" as NSString, forPragmaNamed: "journal_mode")
        container.persistentStoreDescriptions = [store]
        return container
    }

    func startSession(_ session: Session, info: Info.AppInfo) {
        backgroundContext.performAndWait {
            self.session = session
            saveEntity(for: session, info: info)
        }
    }

    private func saveEntity(for session: Session, info: Info.AppInfo) {
        let existing = try? backgroundContext.first(LoggerSessionEntity.self) {
            $0.predicate = NSPredicate(format: "id == %@", session.id as NSUUID)
        }
        guard existing == nil else { return }

        // Start a new session
        let entity = LoggerSessionEntity(context: backgroundContext)
        entity.createdAt = session.startDate
        entity.id = session.id
        entity.version = info.version
        entity.build = info.build
        try? backgroundContext.save()
    }
}

// MARK: - LoggerStore (Storing Messages)

extension LoggerStore {
    /// Stores the given message.
    public func storeMessage(createdAt: Date? = nil, label: String, level: Level, message: String, metadata: [String: MetadataValue]? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        handle(.messageStored(.init(
            createdAt: createdAt ?? configuration.makeCurrentDate(),
            label: label,
            level: level,
            message: message,
            metadata: metadata?.unpack(),
            file: file,
            function: function,
            line: line
        )))
    }

    /// Stores the network request.
    ///
    /// - note: If you want to store incremental updates to the task, use
    /// `NetworkLogger` instead.
    public func storeRequest(_ request: URLRequest, response: URLResponse?, error: Swift.Error?, data: Data?, metrics: URLSessionTaskMetrics? = nil, label: String? = nil) {
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
            label: label
        )))
    }

    /// Handles event created by the current store and dispatches it to observers.
    func handle(_ event: Event) {
        guard let event = configuration.willHandleEvent(event) else {
            return
        }
        perform { _ in
            self._handle(event)
        }
        events.send(event)
    }

    /// Handles event emitted by the external store.
    func handleExternalEvent(_ event: Event) {
        perform { _ in self._handle(event) }
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
        message.label = event.label
        message.session = session.id
        message.text = event.message
        message.file = (event.file as NSString).lastPathComponent
        message.function = event.function
        message.line = Int32(event.line)
        if let metadata = event.metadata, !metadata.isEmpty {
            message.rawMetadata = KeyValueEncoding.encodeKeyValuePairs(metadata, sanitize: true)
        }
    }

    private func process(_ event: Event.NetworkTaskCreated) {
        let entity = findOrCreateTask(forTaskId: event.taskId, taskType: event.taskType, createdAt: event.createdAt, label: event.label, url: event.originalRequest.url)
        
        entity.url = event.originalRequest.url?.absoluteString
        entity.host = event.originalRequest.url.flatMap { $0.getHost() }
        entity.httpMethod = event.originalRequest.httpMethod
        entity.requestState = NetworkTaskEntity.State.pending.rawValue
        entity.originalRequest = makeRequest(for: event.originalRequest)
        entity.currentRequest = event.currentRequest.map(makeRequest)
        requestsCache = [:]
        responsesCache = [:]
    }

    private func process(_ event: Event.NetworkTaskProgressUpdated) {
        guard let request = findTask(forTaskId: event.taskId) else {
            return
        }
        let progress = request.progress ?? {
            let progress = NetworkTaskProgressEntity(context: backgroundContext)
            request.progress = progress
            return progress
        }()
        progress.completedUnitCount = event.completedUnitCount
        progress.totalUnitCount = event.totalUnitCount
    }

    private func process(_ event: Event.NetworkTaskCompleted) {
        let entity = findOrCreateTask(forTaskId: event.taskId, taskType: event.taskType, createdAt: event.createdAt, label: event.label, url: event.originalRequest.url)

        entity.url = event.originalRequest.url?.absoluteString
        entity.host = event.originalRequest.url.flatMap { $0.getHost() }
        entity.httpMethod = event.originalRequest.httpMethod
        entity.statusCode = Int32(event.response?.statusCode ?? 0)
        entity.responseContentType = event.response?.contentType?.type
        let isFailure = event.error != nil || event.response?.isSuccess == false
        entity.requestState = (isFailure ? NetworkTaskEntity.State.failure : .success).rawValue

        // Populate response/request data
        let responseContentType = event.response?.contentType

        if let requestBody = event.requestBody {
            let requestContentType = event.originalRequest.contentType
            entity.requestBody = storeBlob(requestBody, contentType: requestContentType)
        }
        if let responseData = event.responseBody {
            entity.responseBody = storeBlob(responseData, contentType: responseContentType)
        }

        switch event.taskType {
        case .dataTask:
            entity.requestBodySize = Int64(event.requestBody?.count ?? 0)
            entity.responseBodySize = Int64(event.responseBody?.count ?? 0)
        case .downloadTask:
            entity.responseBodySize = event.metrics?.transactions.last(where: {
                $0.fetchType == .networkLoad
            })?.transferSize.responseBodyBytesReceived ?? entity.progress?.completedUnitCount ?? -1
        case .uploadTask:
            entity.requestBodySize = event.metrics?.transactions.last(where: {
                $0.fetchType == .networkLoad
            })?.transferSize.requestBodyBytesSent ?? Int64(event.requestBody?.count ?? -1)
        default:
            break
        }

        let transactions = event.metrics?.transactions ?? []
        entity.isFromCache = transactions.last?.fetchType == .localCache || (transactions.last?.fetchType == .networkLoad && transactions.last?.response?.statusCode == 304)

        if let metrics = event.metrics {
            entity.startDate = metrics.taskInterval.start
            entity.duration = metrics.taskInterval.duration
            entity.redirectCount = Int16(min(Int(Int16.max), metrics.redirectCount))
            entity.transactions = Set(metrics.transactions.enumerated().map(makeTransaction))
        }

        if let error = event.error {
            entity.errorCode = Int32(error.code)
            entity.errorDomain = error.domain
            entity.errorDebugDescription = error.debugDescription
            entity.underlyingError = error.underlyingError.flatMap { try? JSONEncoder().encode($0) }
        }

        entity.originalRequest.map(backgroundContext.delete)
        entity.currentRequest.map(backgroundContext.delete)

        entity.originalRequest = makeRequest(for: event.originalRequest)
        entity.currentRequest = event.currentRequest.map(makeRequest)
        entity.response = event.response.map(makeResponse)
        entity.rawMetadata = {
            guard let responseBody = event.responseBody,
               (responseContentType?.isImage ?? false),
                  let metadata = Graphics.makeMetadata(from: responseBody) else {
                return nil
            }
            return KeyValueEncoding.encodeKeyValuePairs(metadata)
        }()

        // Completed
        if let progress = entity.progress {
            backgroundContext.delete(progress)
            entity.progress = nil
        }

        // Update associated message state
        if let message = entity.message { // Should always be non-nill
            message.line = Int32(entity.requestState)
            if isFailure {
                message.level = Level.error.rawValue
            }
        }

        requestsCache = [:]
        responsesCache = [:]
    }

    private func preprocessData(_ data: Data, contentType: NetworkLogger.ContentType?) -> Data {
        guard data.count > 5000 else { // 5 KB is ok
            return data
        }
        guard configuration.isStoringOnlyImageThumbnails && (contentType?.isImage ?? false) else {
            return data
        }
        guard let thumbnail = Graphics.makeThumbnail(from: data, targetSize: 512),
              let data = Graphics.encode(thumbnail) else {
            return data
        }
        return data
    }

    private func findTask(forTaskId taskId: UUID) -> NetworkTaskEntity? {
        try? backgroundContext.first(NetworkTaskEntity.self) {
            $0.predicate = NSPredicate(format: "taskId == %@", taskId as NSUUID)
        }
    }

    private func findOrCreateTask(forTaskId taskId: UUID, taskType: NetworkLogger.TaskType, createdAt: Date, label: String?, url: URL?) -> NetworkTaskEntity {
        if let entity = findTask(forTaskId: taskId) {
            return entity
        }

        let task = NetworkTaskEntity(context: backgroundContext)
        task.taskId = taskId
        task.taskType = taskType.rawValue
        task.createdAt = createdAt
        task.responseBodySize = -1
        task.requestBodySize = -1
        task.isFromCache = false
        task.session = session.id

        let message = LoggerMessageEntity(context: backgroundContext)
        message.createdAt = createdAt
        message.level = Level.debug.rawValue
        message.label = label ?? "network"
        message.session = session.id
        message.file = ""
        message.function = ""
        message.line = Int32(NetworkTaskEntity.State.pending.rawValue)
        message.text = url?.absoluteString ?? ""

        message.task = task
        task.message = message

        return task
    }

    private func makeRequest(for request: NetworkLogger.Request) -> NetworkRequestEntity {
        if let entity = requestsCache[request] {
            return entity
        }
        let entity = NetworkRequestEntity(context: backgroundContext)
        entity.url = request.url?.absoluteString
        entity.httpMethod = request.httpMethod
        entity.httpHeaders = KeyValueEncoding.encodeKeyValuePairs(request.headers)
        entity.allowsCellularAccess = request.options.contains(.allowsCellularAccess)
        entity.allowsExpensiveNetworkAccess = request.options.contains(.allowsExpensiveNetworkAccess)
        entity.allowsConstrainedNetworkAccess = request.options.contains(.allowsConstrainedNetworkAccess)
        entity.httpShouldHandleCookies = request.options.contains(.httpShouldHandleCookies)
        entity.httpShouldUsePipelining = request.options.contains(.httpShouldUsePipelining)
        entity.timeoutInterval = Int32(clamping: Int.max)
        entity.rawCachePolicy = UInt16(request.cachePolicy.rawValue)
        requestsCache[request] = entity
        return entity
    }

    private func makeResponse(for response: NetworkLogger.Response) -> NetworkResponseEntity {
        if let entity = responsesCache[response] {
            return entity
        }
        let entity = NetworkResponseEntity(context: backgroundContext)
        entity.statusCode = Int16(response.statusCode ?? 0)
        entity.httpHeaders = KeyValueEncoding.encodeKeyValuePairs(response.headers)
        responsesCache[response] = entity
        return entity
    }

    private func makeTransaction(at index: Int, transaction: NetworkLogger.TransactionMetrics) -> NetworkTransactionMetricsEntity {
        let entity = NetworkTransactionMetricsEntity(context: backgroundContext)
        entity.index = Int16(index)
        entity.rawFetchType = Int16(transaction.fetchType.rawValue)
        entity.request = makeRequest(for: transaction.request)
        entity.response = transaction.response.map(makeResponse)
        entity.networkProtocol = transaction.networkProtocol
        entity.localAddress = transaction.localAddress
        entity.remoteAddress = transaction.remoteAddress
        entity.localPort = Int32(transaction.localPort ?? 0)
        entity.remotePort = Int32(transaction.remotePort ?? 0)
        entity.isProxyConnection = transaction.conditions.contains(.isProxyConnection)
        entity.isReusedConnection = transaction.conditions.contains(.isReusedConnection)
        entity.isCellular = transaction.conditions.contains(.isCellular)
        entity.isExpensive = transaction.conditions.contains(.isExpensive)
        entity.isConstrained = transaction.conditions.contains(.isConstrained)
        entity.isMultipath = transaction.conditions.contains(.isMultipath)
        entity.rawNegotiatedTLSProtocolVersion = Int32(transaction.negotiatedTLSProtocolVersion?.rawValue ?? 0)
        entity.rawNegotiatedTLSCipherSuite = Int32(transaction.negotiatedTLSCipherSuite?.rawValue ?? 0)
        entity.fetchStartDate = transaction.timing.fetchStartDate
        entity.domainLookupStartDate = transaction.timing.domainLookupStartDate
        entity.domainLookupEndDate = transaction.timing.domainLookupEndDate
        entity.connectStartDate = transaction.timing.connectStartDate
        entity.secureConnectionStartDate = transaction.timing.secureConnectionStartDate
        entity.secureConnectionEndDate = transaction.timing.secureConnectionEndDate
        entity.connectEndDate = transaction.timing.connectEndDate
        entity.requestStartDate = transaction.timing.requestStartDate
        entity.requestEndDate = transaction.timing.requestEndDate
        entity.responseStartDate = transaction.timing.responseStartDate
        entity.responseEndDate = transaction.timing.responseEndDate
        entity.requestHeaderBytesSent = transaction.transferSize.requestHeaderBytesSent
        entity.requestBodyBytesBeforeEncoding = transaction.transferSize.requestBodyBytesBeforeEncoding
        entity.requestBodyBytesSent = transaction.transferSize.requestBodyBytesSent
        entity.responseHeaderBytesReceived = transaction.transferSize.responseHeaderBytesReceived
        entity.responseBodyBytesAfterDecoding = transaction.transferSize.responseBodyBytesAfterDecoding
        entity.responseBodyBytesReceived = transaction.transferSize.responseBodyBytesReceived
        return entity
    }

    // MARK: - Managing Blobs

    private func storeBlob(_ data: Data, contentType: NetworkLogger.ContentType?) -> LoggerBlobHandleEntity? {
        let data = preprocessData(data, contentType: contentType)

        guard !data.isEmpty else {
            return nil // Sanity check
        }
        let sizeLimit = min(Int(Int32.max), configuration.responseBodySizeLimit)
        guard data.count < sizeLimit else {
            return nil
        }
        let key = data.sha1
        let existingEntity = try? backgroundContext.first(LoggerBlobHandleEntity.self) {
            $0.predicate = NSPredicate(format: "key == %@", key as NSData)
        }
        if let entity = existingEntity {
            entity.linkCount += 1
            return entity
        }

        let entity = LoggerBlobHandleEntity(context: backgroundContext)
        entity.key = key
        entity.linkCount = 1
        entity.rawContentType = contentType?.rawValue
        entity.decompressedSize = Int32(data.count)

        var compressedData: Data?
        if configuration.isBlobCompressionEnabled, let compressed = try? data.compressed(), compressed.count < Int(Double(data.count) * 1.1) {
            compressedData = compressed
        }
        let processedData = compressedData ?? data

        // It's safe to use Int32 because we prevent larger values from being stored
        entity.size = Int32(processedData.count)
        entity.isUncompressed = compressedData == nil
        if processedData.count <= configuration.inlineLimit {
            entity.inlineData = processedData
        } else {
            try? processedData.write(to: makeBlobURL(for: key.hexString))
        }
        return entity
    }

    private func unlink(_ blob: LoggerBlobHandleEntity) {
        blob.linkCount -= 1
        if blob.linkCount == 0 {
            if blob.inlineData == nil {
                try? Files.removeItem(at: makeBlobURL(for: blob.key.hexString))
            }
            backgroundContext.delete(blob)
        }
    }

    private func makeBlobURL(for key: String) -> URL {
        blobsURL.appending(filename: key)
    }

    func getDecompressedData(for entity: LoggerBlobHandleEntity) -> Data? {
        getDecompressedData(for: entity.inlineData, key: entity.key, isCompressed: !entity.isUncompressed)
    }

    func getDecompressedData(for inlineData: Data?, key: Data, isCompressed: Bool) -> Data? {
        guard let data = inlineData ?? getRawData(forKey: key.hexString) else { return nil }
        return isCompressed ? decompress(data) : data
    }

    public func getBlobData(forKey key: String) -> Data? {
        guard let data = getRawData(forKey: key) else { return nil }
        return configuration.isBlobCompressionEnabled ? decompress(data) : data // This won't work in some scenarios
    }

    private func getRawData(forKey key: String) -> Data? {
        switch document {
        case .package:
            return try? Data(contentsOf: makeBlobURL(for: key))
        case let .archive(_, document):
            return document.getBlob(forKey: key)
        }
    }

    private func decompress(_ data: Data) -> Data? {
        try? data.decompressed()
    }

    // MARK: - Performing Changes

    private func perform(_ changes: @escaping (NSManagedObjectContext) -> Void) {
        guard !isArchive else { return }

        if options.contains(.synchronous) {
            backgroundContext.performAndWait {
                changes(backgroundContext)
                self.saveAndReset()
            }
        } else {
            backgroundContext.perform {
                changes(self.backgroundContext)
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
        do {
            try backgroundContext.save()
        } catch {
#if DEBUG
            debugPrint(error)
#endif
        }
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
    public func allTasks() throws -> [NetworkTaskEntity] {
        try viewContext.fetch(NetworkTaskEntity.self, sortedBy: \.createdAt)
    }

    /// Removes sessions with the given IDs.
    public func removeSessions(withIDs sessionIDs: Set<UUID>) {
        perform { _ in
            try? self._removeSessions(withIDs: sessionIDs)
        }
    }

    private func _removeSessions(withIDs sessionIDs: Set<UUID>, isInverted: Bool = false) throws {
        try deleteEntities(for: {
            let request = LoggerSessionEntity.fetchRequest()
            let predicate = NSPredicate(format: "id IN %@", sessionIDs)
            request.predicate = isInverted ? NSCompoundPredicate(notPredicateWithSubpredicate: predicate) : predicate
            return request
        }())

        var predicate = NSPredicate(format: "session IN %@", sessionIDs)
        predicate = isInverted ? NSCompoundPredicate(notPredicateWithSubpredicate: predicate) : predicate
        try removeMessages(with: predicate)
    }

    /// Removes all of the previously recorded messages.
    public func removeAll() {
        perform { _ in self._removeAll() }
    }

    private func _removeAll() {
        switch document {
        case .package:
            try? deleteEntities(for: LoggerMessageEntity.fetchRequest())
            try? deleteEntities(for: LoggerBlobHandleEntity.fetchRequest())
            try? deleteEntities(for: LoggerSessionEntity.fetchRequest())
            saveEntity(for: session, info: .make())

            try? Files.removeItem(at: blobsURL)
            Files.createDirectoryIfNeeded(at: blobsURL)
        case .archive:
            break // Do nothing, readonly
        }
    }

    /// Safely closes the database and removes all information from the store.
    ///
    /// - note: After the store is destroyed, you can't write any new messages to it.
    public func destroy() throws {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            if let storeURL = store.url {
                try coordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: [:])
            }
        }
        try Files.removeItem(at: storeURL)
    }

    /// Safely closes the database.
    public func close() throws {
        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }
}

// MARK: - LoggerStore (Export)

extension LoggerStore {
    public enum DocumentType {
        /// A package (directory) with a Pulse database (optimized for writing)
        case package
        /// A document (readonly, archive, optimized to storage and sharing)
        case archive
    }

    /// Store export options.
    public struct ExportOptions {
        /// A predicate describing which messages (``LoggerMessageEntity``) to export.
        public var predicate: NSPredicate?
        /// A list of sessions to export.
        public var sessions: Set<UUID>?

        /// Initializes the store with the given options.
        public init(predicate: NSPredicate? = nil, sessions: Set<UUID>? = nil) {
            self.predicate = predicate
            self.sessions = sessions
        }
    }

    /// Creates a copy of the current store at the given URL. The created copy
    /// has `.pulse` extension.
    ///
    /// - parameters:
    ///   - targetURL: The destination directory must already exist. If the
    ///   file at the destination URL already exists, throws an error.
    ///   - documentType: The document type. By default, `.archive`, which is optimized
    ///   for size and sharing. See ``LoggerStore/DocumentType`` for more info.
    ///   - options: The other sharing options.
    ///
    /// - returns: The information about the created store.
    @discardableResult
    public func export(to targetURL: URL, as docType: DocumentType = .archive, options: ExportOptions = .init()) async throws -> Info {
        try await Task.detached(priority: .userInitiated) {
            try self._export(to: targetURL, as: docType, options: options)
        }.value
    }

    @discardableResult
    private func _export(to targetURL: URL, as docType: DocumentType, options: ExportOptions) throws -> Info {
        guard !FileManager.default.fileExists(atPath: targetURL.path) else {
            throw LoggerStore.Error.fileAlreadyExists
        }
        switch docType {
        case .archive:
            return try _exportAsArchive(to: targetURL, options: options)
        case .package:
            return try _exportAsPackage(to: targetURL, options: options)
        }
    }

    // MARK: Export as Package

    private func _exportAsPackage(to targetURL: URL, options: ExportOptions) throws -> Info {
        let temporary = TemporaryDirectory()
        defer { temporary.remove() }

        // Create the manifest
        let manifest = Manifest(storeId: UUID(), version: .currentStoreVersion)
        try JSONEncoder().encode(manifest).write(to: temporary.url.appending(filename: manifestFilename))

        // Copy the database
        let databaseURL = temporary.url.appending(filename: databaseFilename)
        try container.persistentStoreCoordinator.createCopyOfStore(at: databaseURL)

        // Temporary open the target store (order is important)
        let target = try LoggerStore(storeURL: temporary.url, options: .readonly)
        defer { try? target.close() }

        // Remove unwanted messages
        backgroundContext.performAndWait {
            try? target._removeUnwantedExportableContent(for: options)
        }

        // Copy required blobs
        backgroundContext.performAndWait {
            try? _exportBlobs(to: target)
        }

        let info = try target.info()
        try target.close() // important: has to be called before `move`.

        try Files.moveItem(at: temporary.url, to: targetURL)
        return info
    }

    /// Removes any content that doesn't match the given options.
    ///
    /// - note: It was the simpler option to implement than copying entities
    /// one by one. The performance is acceptable for a rare operation like this,
    /// but there might be better ways to implement this.
    private func _removeUnwantedExportableContent(for options: ExportOptions) throws {
        // Remove sessions based on the options
        if let sessions = options.sessions {
            try _removeSessions(withIDs: sessions, isInverted: true)
        }
        // Remove messages based on the predicates
        if let predicate = options.predicate {
            try removeMessages(with: NSCompoundPredicate(notPredicateWithSubpredicate: predicate))
        }
        if backgroundContext.hasChanges {
            try backgroundContext.save()
        }
    }

    /// Moves the blobs from the source store to the `target` store, keeping
    /// only the entities present in the `target` store.
    private func _exportBlobs(to target: LoggerStore) throws {
        let blobs = try target.backgroundContext.fetch(LoggerBlobHandleEntity.self) {
            $0.predicate = NSPredicate(format: "inlineData = nil")
        }
        Files.createDirectoryIfNeeded(at: target.blobsURL)
        for key in blobs.map(\.key.hexString) {
            switch document {
            case .package:
                try? Files.copyItem(at: makeBlobURL(for: key), to: target.makeBlobURL(for: key))
            case let .archive(_, document):
                try? document.getBlob(forKey: key)?.write(to: target.makeBlobURL(for: key))
            }
        }
    }

    // MARK: Export as Archive

    private func _exportAsArchive(to targetURL: URL, options: ExportOptions) throws -> Info {
        if options.predicate != nil || options.sessions != nil {
            let temporary = TemporaryDirectory()
            defer { temporary.remove() }

            let tempStoreURL = temporary.url.appending(filename: "temp.pulse")
            try _export(to: tempStoreURL, as: .package, options: options)

            let target = try LoggerStore(storeURL: tempStoreURL, options: .readonly)
            defer { try? target.close() }

            return try target._exportPackageAsArchive(to: targetURL)
        } else {
            switch document {
            case .package:
                return try _exportPackageAsArchive(to: targetURL)
            case .archive:
                try Files.copyItem(at: storeURL, to: targetURL)
                return try Info.make(storeURL: targetURL)
            }
        }
    }

    private func _exportPackageAsArchive(to targetURL: URL) throws -> Info {
        if case .archive = document {
            assertionFailure("Unsupported store type")
        }

        let temporary = TemporaryDirectory()
        defer { temporary.remove() }

        // Create copy of the store
        let databaseURL = temporary.url.appending(filename: databaseFilename)
        try container.persistentStoreCoordinator.createCopyOfStore(at: databaseURL)

        var info = try self.info()

        let document = try PulseDocument(documentURL: targetURL)
        var totalSize: Int64 = 0

        return try document.context.performAndReturn {
            // Add database
            let documentBlob = PulseBlobEntity(context: document.context)
            documentBlob.key = "database"
            documentBlob.data = try Data(contentsOf: databaseURL).compressed()
            totalSize += Int64(documentBlob.data.count)

            // Add blobs
            if Files.fileExists(atPath: blobsURL.path) {
                let blobURLs = try Files.contentsOfDirectory(at: blobsURL, includingPropertiesForKeys: nil)
                for chunk in blobURLs.chunked(into: 100) {
                    var objects: [[String: Any]] = []
                    for blobURL in chunk {
                        if let data = try? Data(contentsOf: blobURL) {
                            objects.append([
                                "key": blobURL.lastPathComponent,
                                "data": data
                            ])
                            totalSize += Int64(data.count)
                        }
                    }
                    try document.context.execute(NSBatchInsertRequest(entityName: String(describing: PulseBlobEntity.self), objects: objects))
                }
            }

            // Add store info
            info.storeId = UUID()
            // Chicken and an egg problem: don't know the exact size.
            // The output file is also going to be about 10-20% larger because of
            // the unused pages in the sqlite database.
            info.totalStoreSize = totalSize + 500 // info is roughly 500 bytes
            info.creationDate = configuration.makeCurrentDate()
            info.modifiedDate = info.creationDate

            let infoBlob = PulseBlobEntity(context: document.context)
            infoBlob.key = "info"
            infoBlob.data = try JSONEncoder().encode(info)

            try document.context.save()
            try? document.close()

            return info
        }
    }

    @available(*, deprecated, message: "Deprecated") // 3.6
    public func copy(to targetURL: URL, predicate: NSPredicate? = nil) throws -> Info {
        try _export(to: targetURL, as: .archive, options: .init(predicate: predicate))
    }
}

// MARK: - LoggerStore (Sweep)

extension LoggerStore {
    var isAutomaticSweepNeeded: Bool {
        guard options.contains(.sweep) && !isArchive else { return false }
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
        let sessionIDs = try backgroundContext.fetch(LoggerSessionEntity.self) {
            $0.predicate = NSPredicate(format: "createdAt < %@", cutoffDate as NSDate)
        }.map(\.id)
        if !sessionIDs.isEmpty {
            try _removeSessions(withIDs: Set(sessionIDs))
        }
    }

    private func reduceDatabaseSize() throws {
        let size = try storeURL.directoryTotalSize()

        guard size > configuration.sizeLimit else {
            return // All good, no need to perform any work.
        }

        // First remove some old messages
        let messages = try backgroundContext.fetch(LoggerMessageEntity.self, sortedBy: \.createdAt, ascending: false)
        let count = messages.count
        guard count > 10 else { return } // Sanity check

        let cutoffDate = messages[Int(Double(count) * configuration.trimRatio)].createdAt
        try removeMessages(before: cutoffDate)
    }

    private func removeMessages(before date: Date) throws {
        let predicate = NSPredicate(format: "createdAt < %@", date as NSDate)
        try removeMessages(with: predicate)
    }

    private func removeMessages(with predicate: NSPredicate) throws {
        // Unlink blobs associated with the requests the store is about to remove
        let messages = try backgroundContext.fetch(LoggerMessageEntity.self) {
            $0.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, NSPredicate(format: "task != NULL")])
        }
        for message in messages {
            if let task = message.task {
                task.requestBody.map(unlink)
                task.responseBody.map(unlink)
            }
        }

        // Remove messages using an efficient batch request
        let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "LoggerMessageEntity")
        deleteRequest.predicate = predicate
        try deleteEntities(for: deleteRequest)
    }

    private func reduceBlobStoreSize() throws {
        var currentSize = try getBlobsSize()

        guard currentSize > configuration.blobSizeLimit else {
            return // All good, no need to remove anything
        }
        let tasks = try backgroundContext.fetch(NetworkTaskEntity.self, sortedBy: \.createdAt) {
            $0.predicate = NSPredicate(format: "requestBody != NULL OR responseBody != NULL")
        }
        let targetSize = Int(Double(configuration.blobSizeLimit) * configuration.trimRatio)
        func _unlink(_ blob: LoggerBlobHandleEntity) {
            unlink(blob)
            currentSize -= Int64(blob.size)
        }
        for task in tasks where currentSize > targetSize {
            if let requestBody = task.requestBody {
                _unlink(requestBody)
                task.requestBody = nil
            }
            if let responseBody = task.responseBody {
                _unlink(responseBody)
                task.responseBody = nil
            }
        }
    }

    private func getBlobsSize(isDecompressed: Bool = false) throws -> Int64 {
        let request = LoggerBlobHandleEntity.fetchRequest()

        let description = NSExpressionDescription()
        description.name = "sum"

        let keypathExp1 = NSExpression(forKeyPath: isDecompressed ? "decompressedSize" : "size")
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

extension LoggerStore {
    /// Returns the current store's info.
    ///
    /// - important Thread-safe. But must NOT be called inside the `backgroundContext` queue.
    public func info() throws -> Info {
        switch document {
        case let .archive(info, _):
            return info
        case .package:
            return try backgroundContext.performAndReturn { try self._info() }
        }
    }

    private func _info() throws -> Info {
        let databaseAttributes = try Files.attributesOfItem(atPath: databaseURL.path)

        let messageCount = try backgroundContext.count(for: LoggerMessageEntity.self)
        let taskCount = try backgroundContext.count(for: NetworkTaskEntity.self)
        let blobCount = try backgroundContext.count(for: LoggerBlobHandleEntity.self)

        return Info(
            storeId: manifest.storeId,
            storeVersion: manifest.version.description,
            creationDate: (databaseAttributes[.creationDate] as? Date) ?? Date(),
            modifiedDate: (databaseAttributes[.modificationDate] as? Date) ?? Date(),
            messageCount: messageCount - taskCount,
            taskCount: taskCount,
            blobCount: blobCount,
            totalStoreSize: try storeURL.directoryTotalSize(),
            blobsSize: try getBlobsSize(),
            blobsDecompressedSize: try getBlobsSize(isDecompressed: true),
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
                guard let message = $0.object(with: message.objectID) as? LoggerMessageEntity else { return }
                self._togglePin(for: message)
            }
        }

        public func togglePin(for task: NetworkTaskEntity) {
            guard let store = store else { return }
            store.perform {
                guard let task = $0.object(with: task.objectID) as? NetworkTaskEntity else { return }
                task.message.map(self._togglePin)
            }
        }

        public func removeAllPins() {
            guard let store = store else { return }
            store.perform {
                let messages = try? $0.fetch(LoggerMessageEntity.self) {
                    $0.predicate = NSPredicate(format: "isPinned == YES")
                }
                for message in messages ?? [] {
                    self._togglePin(for: message)
                }
            }
        }

        private func _togglePin(for message: LoggerMessageEntity) {
            message.isPinned.toggle()
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
        try JSONEncoder().encode(manifest).write(to: manifestURL)
    }
}

// MARK: - LoggerStore (Error)

extension LoggerStore {
    public enum Error: Swift.Error, LocalizedError {
        case fileDoesntExist
        case storeInvalid
        case unsupportedVersion(version: String, minimumSupportedVersion: String)
        case documentIsReadonly
        case fileAlreadyExists
        case unknownError

        public var errorDescription: String? {
            switch self {
            case .fileDoesntExist: return "File doesn't exist"
            case .storeInvalid: return "Store format is invalid"
            case .documentIsReadonly: return "Document is readonly"
            case let .unsupportedVersion(version, minimumSupportedVersion): return "The store was created by with Pulse vesrion \(version). Minimum supported version is \(minimumSupportedVersion)."
            case .fileAlreadyExists: return "The file at the given location already exists"
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

        init(storeId: UUID, version: Version) {
            self.storeId = storeId
            self.version = version
        }

        init?(url: URL) {
            guard let data = try? Data(contentsOf: url),
                  let manifest = try? JSONDecoder().decode(Manifest.self, from: data) else {
                return nil
            }
            self = manifest
        }
    }
}

extension Version {
    static let minimumSupportedVersion = Version(3, 1, 0)
    static let currentStoreVersion = Version(3, 6, 0)
    static let currentProtocolVersion = Version(4, 0, 0)
}

// MARK: - Constants

let manifestFilename = "manifest.json"
let databaseFilename = "logs.sqlite"
let infoFilename = "info.json"
let blobsDirectoryName = "blobs"

private enum PulseDocumentType {
    /// A plain directory (aka "package"). If it has a `.pulse` file extension,
    /// it can be automatically opened by the Pulse apps.
    case package
    /// An archive created by exporting the store.
    case archive(LoggerStore.Info, PulseDocument)
}
