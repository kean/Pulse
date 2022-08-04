// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

// MARK: - LoggerStore (NSManagedObjectModel)

extension LoggerStore {
    /// Returns Core Data model used by the store.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let message = NSEntityDescription(name: "LoggerMessageEntity", class: LoggerMessageEntity.self)
        let metadata = NSEntityDescription(name: "LoggerMetadataEntity", class: LoggerMetadataEntity.self)
        let request = NSEntityDescription(name: "LoggerNetworkRequestEntity", class: LoggerNetworkRequestEntity.self)
        let requestProgress = NSEntityDescription(name: "LoggerNetworkRequestProgressEntity", class: LoggerNetworkRequestProgressEntity.self)
        let requestDetails = NSEntityDescription(name: "LoggerNetworkRequestDetailsEntity", class: LoggerNetworkRequestDetailsEntity.self)
        let blob = NSEntityDescription(name: "LoggerBlobHandleEntity", class: LoggerBlobHandleEntity.self)
        let inlinedData = NSEntityDescription(name: "LoggerInlineDataEntity", class: LoggerInlineDataEntity.self)

        message.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "isPinned", type: .booleanAttributeType),
            NSAttributeDescription(name: "session", type: .stringAttributeType),
            NSAttributeDescription(name: "level", type: .stringAttributeType),
            NSAttributeDescription(name: "levelOrder", type: .integer16AttributeType),
            NSAttributeDescription(name: "label", type: .stringAttributeType),
            NSAttributeDescription(name: "text", type: .stringAttributeType),
            NSRelationshipDescription.make(name: "metadata", type: .oneToMany, entity: metadata),
            NSAttributeDescription(name: "file", type: .stringAttributeType),
            NSAttributeDescription(name: "filename", type: .stringAttributeType),
            NSAttributeDescription(name: "function", type: .stringAttributeType),
            NSAttributeDescription(name: "line", type: .integer32AttributeType),
            NSAttributeDescription(name: "requestState", type: .integer16AttributeType),
            NSRelationshipDescription.make(name: "request", type: .oneToOne(isOptional: true), entity: request)
        ]

        metadata.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "value", type: .stringAttributeType)
        ]

        request.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "isPinned", type: .booleanAttributeType),
            NSAttributeDescription(name: "session", type: .stringAttributeType),
            NSAttributeDescription(name: "taskId", type: .UUIDAttributeType),
            NSAttributeDescription(name: "rawTaskType", type: .stringAttributeType),
            NSAttributeDescription(name: "url", type: .stringAttributeType),
            NSAttributeDescription(name: "host", type: .stringAttributeType),
            NSAttributeDescription(name: "httpMethod", type: .stringAttributeType),
            NSAttributeDescription(name: "errorDomain", type: .stringAttributeType),
            NSAttributeDescription(name: "errorCode", type: .integer32AttributeType),
            NSAttributeDescription(name: "statusCode", type: .integer32AttributeType),
            NSAttributeDescription(name: "startDate", type: .dateAttributeType),
            NSAttributeDescription(name: "duration", type: .doubleAttributeType),
            NSAttributeDescription(name: "contentType", type: .stringAttributeType),
            NSAttributeDescription(name: "requestState", type: .integer16AttributeType),
            NSAttributeDescription(name: "redirectCount", type: .integer16AttributeType),
            NSAttributeDescription(name: "requestBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "responseBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "isFromCache", type: .booleanAttributeType),
            NSRelationshipDescription.make(name: "details", type: .oneToOne(), entity: requestDetails),
            NSRelationshipDescription.make(name: "message", type: .oneToOne(), entity: message),
            NSRelationshipDescription.make(name: "requestBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            NSRelationshipDescription.make(name: "responseBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            NSRelationshipDescription.make(name: "progress", type: .oneToOne(isOptional: true), entity: requestProgress)
        ]

        requestDetails.properties = [
            NSAttributeDescription(name: "originalRequest", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "currentRequest", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "response", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "error", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "metrics", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "metadata", type: .binaryDataAttributeType)
        ]

        requestProgress.properties = [
            NSAttributeDescription(name: "completedUnitCount", type: .integer64AttributeType),
            NSAttributeDescription(name: "totalUnitCount", type: .integer64AttributeType)
        ]

        blob.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "size", type: .integer64AttributeType),
            NSAttributeDescription(name: "linkCount", type: .integer16AttributeType),
            NSRelationshipDescription.make(name: "inlineData", type: .oneToOne(isOptional: true), entity: inlinedData)
        ]

        inlinedData.properties = [
            NSAttributeDescription(name: "data", type: .binaryDataAttributeType)
        ]

        model.entities = [message, metadata, request, requestDetails, requestProgress, blob, inlinedData]
        return model
    }()
}

// MARK: - NSManagedObjects

public final class LoggerMessageEntity: NSManagedObject {
    @NSManaged public var createdAt: Date
    @NSManaged public var isPinned: Bool
    @NSManaged public var session: String
    @NSManaged public var level: String
    @NSManaged public var levelOrder: Int16
    @NSManaged public var label: String
    @NSManaged public var text: String
    @NSManaged public var metadata: Set<LoggerMetadataEntity>
    @NSManaged public var file: String
    @NSManaged public var filename: String
    @NSManaged public var function: String
    @NSManaged public var line: Int32
    @NSManaged public var requestState: Int16
    @NSManaged public var request: LoggerNetworkRequestEntity?
}

public final class LoggerMetadataEntity: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
}

public final class LoggerNetworkRequestEntity: NSManagedObject {
    // Primary
    @NSManaged public var createdAt: Date
    @NSManaged public var isPinned: Bool
    @NSManaged public var session: String
    @NSManaged public var taskId: UUID?
    @NSManaged public var rawTaskType: String?
    @NSManaged public var message: LoggerMessageEntity?

    // MARK: Request

    @NSManaged public var url: String?
    @NSManaged public var host: String?
    @NSManaged public var httpMethod: String?

    // MARK: Response

    @NSManaged public var statusCode: Int32
    @NSManaged public var errorDomain: String?
    @NSManaged public var errorCode: Int32
    /// Response content-type.
    @NSManaged public var contentType: String?
    /// Returns `true` if the response was returned from the local cache.
    @NSManaged public var isFromCache: Bool

    // MARK: State

    /// Contains ``State-swift.enum`` raw value.
    @NSManaged public var requestState: Int16
    /// Request progress.
    ///
    /// - note: The entity is created lazily when the first progress report
    /// is delivered. If no progress updates are delivered, it's never created.
    @NSManaged public var progress: LoggerNetworkRequestProgressEntity?

    // MARK: Metrics (Denormalized)

    // Timing
    /// Request start date.
    @NSManaged public var startDate: Date?
    /// Request end date.
    public var endDate: Date? {
        startDate.map { $0.addingTimeInterval(duration) }
    }
    /// Total request duration end date.
    @NSManaged public var duration: Double
    /// Number of redirects.
    @NSManaged public var redirectCount: Int16

    // MARK: Details

    /// Request details.
    @NSManaged public var details: LoggerNetworkRequestDetailsEntity
    /// The request body handle.
    @NSManaged public var requestBody: LoggerBlobHandleEntity?
    /// The response body handle.
    @NSManaged public var responseBody: LoggerBlobHandleEntity?
    /// The size of the request body.
    @NSManaged public var requestBodySize: Int64
    /// The size of the response body.
    @NSManaged public var responseBodySize: Int64

    // MARK: Helpers

    /// Returns request state.
    public var state: LoggerNetworkRequestEntity.State {
        if let state = LoggerNetworkRequestEntity.State(rawValue: requestState) {
            return state
        }
        // For backward-compatibility.
        let isFailure = errorCode != 0 || (statusCode != 0 && !(200..<400).contains(statusCode))
        return isFailure ? .failure : .success
    }

    /// Returns task interval (if available from metrics).
    public var taskInterval: DateInterval? {
        guard let startDate = self.startDate, let endDate = self.endDate else {
            return nil
        }
        return DateInterval(start: startDate, end: endDate)
    }

    /// Returns task type
    public var taskType: NetworkLogger.TaskType? {
        rawTaskType.flatMap(NetworkLogger.TaskType.init)
    }

    public enum State: Int16 {
        case pending = 1
        case success = 2
        case failure = 3
    }
}

/// Indicates current download or upload progress.
public final class LoggerNetworkRequestProgressEntity: NSManagedObject {
    /// Indicates current download or upload progress.
    @NSManaged public var completedUnitCount: Int64
    /// Indicates current download or upload progress.
    @NSManaged public var totalUnitCount: Int64
}

/// Details associated with the request.
public final class LoggerNetworkRequestDetailsEntity: NSManagedObject {
    /// Contains JSON-encoded ``NetworkLogger/Request``.
    @NSManaged public var originalRequest: Data?
    /// Contains JSON-encoded ``NetworkLogger/Request``.
    @NSManaged public var currentRequest: Data?
    /// Contains JSON-encoded ``NetworkLogger/Response``.
    @NSManaged public var response: Data?
    /// Contains JSON-encoded ``NetworkLogger/ResponseError``.
    @NSManaged public var error: Data?
    /// Contains JSON-encoded ``NetworkLogger/Metrics``.
    @NSManaged public var metrics: Data?
    /// Contains JSON-encoded metadata (`[String: String]`).
    @NSManaged public var metadata: Data?
}

/// Doesn't contain any data, just the key and some additional payload.
public final class LoggerBlobHandleEntity: NSManagedObject {
    /// A blob hash (sha1, 40 characters).
    @NSManaged public var key: String

    /// A blob size.
    @NSManaged public var size: Int64

    /// A number of requests referencing it.
    @NSManaged var linkCount: Int16

    /// The logger inlines small blobs in a separate table in the database which
    /// significantly [reduces](https://www.sqlite.org/intern-v-extern-blob.html)
    /// the total allocated size for these files and improves the overall performance.
    ///
    /// The larger blobs are stored in an file system. And when you export a Pulse
    /// document, the larger blobs are read from the created archive on-demand,
    /// significantly reducing the speed with this the documents are opened and
    /// reducing space usage.
    ///
    /// To access data, use the convenience ``data`` property.
    @NSManaged var inlineData: LoggerInlineDataEntity?

    static let inlineLimit = 32768 // 32 KB

    /// Returns the associated data.
    ///
    /// - important: This property only works with `NSManagedObjectContext` instances
    /// created by the ``LoggerStore``. If you are reading the database manually,
    /// you'll need to access the files directly by using the associated ``key``
    /// that matches the name o the file in the `/blobs` directly in the store
    /// directory.
    public var data: Data? {
        if let inlineData = self.inlineData?.data {
            return inlineData
        }
        guard let store = managedObjectContext?.userInfo[WeakLoggerStore.loggerStoreKey] as? WeakLoggerStore else {
            return nil // Should never happen unless the object was created outside of the LoggerStore moc
        }
        return store.store?.getBlobData(forKey: key)
    }
}

final class LoggerInlineDataEntity: NSManagedObject {
    @NSManaged var data: Data
}
