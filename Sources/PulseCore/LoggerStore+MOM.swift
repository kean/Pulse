// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

// MARK: - LoggerStore (NSManagedObjectModel)

public extension LoggerStore {
    /// Returns Core Data model used by the store.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let message = NSEntityDescription(name: "LoggerMessageEntity", class: LoggerMessageEntity.self)
        let metadata = NSEntityDescription(name: "LoggerMetadataEntity", class: LoggerMetadataEntity.self)
        let request = NSEntityDescription(name: "LoggerNetworkRequestEntity", class: LoggerNetworkRequestEntity.self)
        let requestDetails = NSEntityDescription(name: "LoggerNetworkRequestDetailsEntity", class: LoggerNetworkRequestDetailsEntity.self)

        metadata.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "value", type: .stringAttributeType)
        ]

        message.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "level", type: .stringAttributeType),
            NSAttributeDescription(name: "levelOrder", type: .integer16AttributeType),
            NSAttributeDescription(name: "label", type: .stringAttributeType),
            NSAttributeDescription(name: "session", type: .stringAttributeType),
            NSAttributeDescription(name: "text", type: .stringAttributeType),
            NSRelationshipDescription.make(name: "metadata", type: .oneToMany, entity: metadata),
            NSAttributeDescription(name: "file", type: .stringAttributeType),
            NSAttributeDescription(name: "filename", type: .stringAttributeType),
            NSAttributeDescription(name: "function", type: .stringAttributeType),
            NSAttributeDescription(name: "line", type: .integer32AttributeType),
            NSAttributeDescription(name: "isPinned", type: .booleanAttributeType),
            NSAttributeDescription(name: "requestState", type: .integer16AttributeType),
            NSRelationshipDescription.make(name: "request", type: .oneToOne(isOptional: true), entity: request)
        ]

        requestDetails.properties = [
            NSAttributeDescription(name: "originalRequest", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "currentRequest", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "response", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "error", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "metrics", type: .binaryDataAttributeType),
        ]

        request.properties = [
            NSAttributeDescription(name: "taskId", type: .UUIDAttributeType),
            NSAttributeDescription(name: "rawTaskType", type: .stringAttributeType),
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "session", type: .stringAttributeType),
            NSAttributeDescription(name: "url", type: .stringAttributeType),
            NSAttributeDescription(name: "host", type: .stringAttributeType),
            NSAttributeDescription(name: "httpMethod", type: .stringAttributeType),
            NSAttributeDescription(name: "errorDomain", type: .stringAttributeType),
            NSAttributeDescription(name: "errorCode", type: .integer32AttributeType),
            NSAttributeDescription(name: "statusCode", type: .integer32AttributeType),
            NSAttributeDescription(name: "duration", type: .doubleAttributeType),
            NSAttributeDescription(name: "contentType", type: .stringAttributeType),
            NSAttributeDescription(name: "requestState", type: .integer16AttributeType),
            NSAttributeDescription(name: "redirectCount", type: .integer16AttributeType),
            NSAttributeDescription(name: "requestBodyKey", type: .stringAttributeType),
            NSAttributeDescription(name: "responseBodyKey", type: .stringAttributeType),
            NSAttributeDescription(name: "requestBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "responseBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "isFromCache", type: .booleanAttributeType),
            NSAttributeDescription(name: "completedUnitCount", type: .integer64AttributeType),
            NSAttributeDescription(name: "totalUnitCount", type: .integer64AttributeType),
            NSRelationshipDescription.make(name: "details", type: .oneToOne(), entity: requestDetails),
            NSRelationshipDescription.make(name: "message", type: .oneToOne(), entity: message)
        ]

        model.entities = [message, metadata, request, requestDetails]
        return model
    }()
}

// MARK: - NSManagedObjects

public final class LoggerMessageEntity: NSManagedObject {
    @NSManaged public var createdAt: Date
    @NSManaged public var level: String
    @NSManaged public var levelOrder: Int16
    @NSManaged public var label: String
    @NSManaged public var session: String
    @NSManaged public var text: String
    @NSManaged public var metadata: Set<LoggerMetadataEntity>
    @NSManaged public var file: String
    @NSManaged public var filename: String
    @NSManaged public var function: String
    @NSManaged public var line: Int32
    @NSManaged public var isPinned: Bool
    @NSManaged public var requestState: Int16
    @NSManaged public var request: LoggerNetworkRequestEntity?
}

public final class LoggerMetadataEntity: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
}

public final class LoggerNetworkRequestEntity: NSManagedObject {
    // Primary
    @NSManaged public var taskId: UUID?
    @NSManaged public var rawTaskType: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var session: String
    @NSManaged public var message: LoggerMessageEntity?

    // Denormalized
    @NSManaged public var url: String?
    @NSManaged public var host: String?
    @NSManaged public var httpMethod: String?
    @NSManaged public var errorDomain: String?
    @NSManaged public var errorCode: Int32
    @NSManaged public var statusCode: Int32
    @NSManaged public var duration: Double
    @NSManaged public var contentType: String?
    /// Contains ``State`` raw value.
    @NSManaged public var requestState: Int16
    @NSManaged public var redirectCount: Int16

    /// Returns request state.
    public var state: LoggerNetworkRequestEntity.State {
        if let state = LoggerNetworkRequestEntity.State(rawValue: requestState) {
            return state
        }
        // For backward-compatibility.
        let isFailure = errorCode != 0 || (statusCode != 0 && !(200..<400).contains(statusCode))
        return isFailure ? .failure : .success
    }

    /// Returns task type
    public var taskType: NetworkLoggerTaskType? {
        rawTaskType.flatMap(NetworkLoggerTaskType.init)
    }

    public enum State: Int16 {
        case pending = 1
        case success = 2
        case failure = 3
    }

    /// Request details.
    @NSManaged public var details: LoggerNetworkRequestDetailsEntity
    /// The key in the blob storage. To get the data, see ``LoggerStore/getData(forKey:)``.
    @NSManaged public var requestBodyKey: String?
    /// The key in the blob storage. To get the data, see ``LoggerStore/getData(forKey:)``.
    @NSManaged public var responseBodyKey: String?
    /// The size of the request body.
    @NSManaged public var requestBodySize: Int64
    /// The size of the response body.
    @NSManaged public var responseBodySize: Int64
    /// Returns `true` if the response was returned from the local cache.
    @NSManaged public var isFromCache: Bool

    /// Indicates current download or upload progress.
    @NSManaged public var completedUnitCount: Int64
    /// Indicates current download or upload progress.
    @NSManaged public var totalUnitCount: Int64
}

public final class LoggerNetworkRequestDetailsEntity: NSManagedObject {
    /// Contains JSON-encoded ``NetworkLoggerRequest``.
    @NSManaged public var originalRequest: Data?
    /// Contains JSON-encoded ``NetworkLoggerRequest``.
    @NSManaged public var currentRequest: Data?
    /// Contains JSON-encoded ``NetworkLoggerResponse``.
    @NSManaged public var response: Data?
    /// Contains JSON-encoded ``NetworkLoggerError``.
    @NSManaged public var error: Data?
    /// Contains JSON-encoded ``NetworkLoggerMetrics``.
    @NSManaged public var metrics: Data?
}

// MARK: - Helpers

private extension NSEntityDescription {
    convenience init<T>(name: String, class: T.Type) where T: NSManagedObject {
        self.init()
        self.name = name
        self.managedObjectClassName = T.self.description()
    }
}

private extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType) {
        self.init()
        self.name = name
        self.attributeType = type
    }
}

private enum RelationshipType {
    case oneToMany
    case oneToOne(isOptional: Bool = false)
}

private extension NSRelationshipDescription {
    static func make(name: String,
                     type: RelationshipType,
                     deleteRule: NSDeleteRule = .cascadeDeleteRule,
                     entity: NSEntityDescription) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.deleteRule = deleteRule
        relationship.destinationEntity = entity
        switch type {
        case .oneToMany:
            relationship.maxCount = 0
            relationship.minCount = 0
        case .oneToOne(let isOptional):
            relationship.maxCount = 1
            relationship.minCount = isOptional ? 0 : 1
        }
        return relationship
    }
}
