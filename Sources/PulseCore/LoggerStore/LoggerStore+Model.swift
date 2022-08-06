// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

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
            NSAttributeDescription(name: "session", type: .UUIDAttributeType),
            NSAttributeDescription(name: "level", type: .integer16AttributeType),
            NSAttributeDescription(name: "label", type: .stringAttributeType),
            NSAttributeDescription(name: "text", type: .stringAttributeType),
            NSRelationshipDescription.make(name: "metadata", type: .oneToMany, entity: metadata),
            NSAttributeDescription(name: "file", type: .stringAttributeType),
            NSAttributeDescription(name: "function", type: .stringAttributeType),
            NSAttributeDescription(name: "line", type: .integer32AttributeType),
            NSRelationshipDescription.make(name: "request", type: .oneToOne(isOptional: true), entity: request)
        ]

        metadata.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "value", type: .stringAttributeType)
        ]

        request.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "isPinned", type: .booleanAttributeType),
            NSAttributeDescription(name: "session", type: .UUIDAttributeType),
            NSAttributeDescription(name: "taskId", type: .UUIDAttributeType),
            NSAttributeDescription(name: "rawTaskType", type: .integer16AttributeType),
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
            NSAttributeDescription(name: "decompressedSize", type: .integer64AttributeType),
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

// MARK: - Helpers

private extension NSEntityDescription {
    convenience init<T>(name: String, class: T.Type) where T: NSManagedObject {
        self.init()
        self.name = name
        self.managedObjectClassName = T.self.description()
    }
}

private extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType, _ configure: (NSAttributeDescription) -> Void = { _ in }) {
        self.init()
        self.name = name
        self.attributeType = type
        configure(self)
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
