// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

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

        do {
            let key = NSAttributeDescription(name: "key", type: .stringAttributeType)
            let value = NSAttributeDescription(name: "value", type: .stringAttributeType)
            metadata.properties = [key, value]
        }

        do {
            let createdAt = NSAttributeDescription(name: "createdAt", type: .dateAttributeType)
            let level = NSAttributeDescription(name: "level", type: .stringAttributeType)
            let levelOrder = NSAttributeDescription(name: "levelOrder", type: .integer16AttributeType)
            let label = NSAttributeDescription(name: "label", type: .stringAttributeType)
            let session = NSAttributeDescription(name: "session", type: .stringAttributeType)
            let text = NSAttributeDescription(name: "text", type: .stringAttributeType)
            let metadata = NSRelationshipDescription.make(name: "metadata", type: .oneToMany, entity: metadata)
            let file = NSAttributeDescription(name: "file", type: .stringAttributeType)
            let function = NSAttributeDescription(name: "function", type: .stringAttributeType)
            let line = NSAttributeDescription(name: "line", type: .integer32AttributeType)
            let isPinned = NSAttributeDescription(name: "isPinned", type: .booleanAttributeType)
            let request = NSRelationshipDescription.make(name: "request", type: .oneToOne(isOptional: true), entity: request)
            message.properties = [createdAt, level, levelOrder, label, session, text, metadata, file, function, line, isPinned, request]
        }

        do {
            let request = NSAttributeDescription(name: "request", type: .binaryDataAttributeType)
            let response = NSAttributeDescription(name: "response", type: .binaryDataAttributeType)
            let error = NSAttributeDescription(name: "error", type: .binaryDataAttributeType)
            let metrics = NSAttributeDescription(name: "metrics", type: .binaryDataAttributeType)
            let requestBodySize = NSAttributeDescription(name: "requestBodySize", type: .integer64AttributeType)
            let responseBodySize = NSAttributeDescription(name: "responseBodySize", type: .integer64AttributeType)
            requestDetails.properties = [request, response, error, metrics, requestBodySize, responseBodySize]
        }

        do {
            let createdAt = NSAttributeDescription(name: "createdAt", type: .dateAttributeType)
            let session = NSAttributeDescription(name: "session", type: .stringAttributeType)
            let url = NSAttributeDescription(name: "url", type: .stringAttributeType)
            let host = NSAttributeDescription(name: "host", type: .stringAttributeType)
            let httpMethod = NSAttributeDescription(name: "httpMethod", type: .stringAttributeType)
            let errorDomain = NSAttributeDescription(name: "errorDomain", type: .stringAttributeType)
            let errorCode = NSAttributeDescription(name: "errorCode", type: .integer32AttributeType)
            let statusCode = NSAttributeDescription(name: "statusCode", type: .integer32AttributeType)
            let duration = NSAttributeDescription(name: "duration", type: .doubleAttributeType)
            let contentType = NSAttributeDescription(name: "contentType", type: .stringAttributeType)
            let isCompleted = NSAttributeDescription(name: "isCompleted", type: .booleanAttributeType)
            let state = NSAttributeDescription(name: "state", type: .integer16AttributeType)
            let requestBodyKey = NSAttributeDescription(name: "requestBodyKey", type: .stringAttributeType)
            let responseBodyKey = NSAttributeDescription(name: "responseBodyKey", type: .stringAttributeType)
            let details = NSRelationshipDescription.make(name: "details", type: .oneToOne(), entity: requestDetails)
            let message = NSRelationshipDescription.make(name: "message", type: .oneToOne(), entity: message)
            request.properties = [createdAt, session, url, host, httpMethod, errorDomain, errorCode, statusCode, duration, contentType, requestBodyKey, responseBodyKey, details, message, isCompleted]
        }

        model.entities = [message, metadata, request, requestDetails]
        return model
    }()
}

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
    @NSManaged public var function: String
    @NSManaged public var line: Int32
    @NSManaged public var isPinned: Bool
    @NSManaged public var request: LoggerNetworkRequestEntity?
}

public final class LoggerMetadataEntity: NSManagedObject {
    @NSManaged public var key: String
    @NSManaged public var value: String
}

public final class LoggerNetworkRequestEntity: NSManagedObject {
    // Primary
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
    @NSManaged public var isCompleted: Bool
    @NSManaged public var state: Int16
    
    public enum State: Int16 {
        case pending = 0 // not used yet
        case success
        case failure
    }

    // Details
    @NSManaged public var details: LoggerNetworkRequestDetailsEntity
    @NSManaged public var requestBodyKey: String? // key to blob storage
    @NSManaged public var responseBodyKey: String? // key to blob storage
}

public final class LoggerNetworkRequestDetailsEntity: NSManagedObject {
    @NSManaged public var request: Data? // NetworkLoggerRequest
    @NSManaged public var response: Data? // NetworkLoggerResponse
    @NSManaged public var error: Data? // NetworkLoggerError
    @NSManaged public var metrics: Data? // NetworkLoggerMetrics
    @NSManaged public var requestBodySize: Int64
    @NSManaged public var responseBodySize: Int64
}
