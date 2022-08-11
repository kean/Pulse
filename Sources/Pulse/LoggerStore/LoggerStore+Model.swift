// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

extension LoggerStore {
    /// Returns Core Data model used by the store.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let message = NSEntityDescription(class: LoggerMessageEntity.self)
        let metadata = NSEntityDescription(class: LoggerMetadataEntity.self)
        let request = NSEntityDescription(class: LoggerNetworkRequestEntity.self)
        let requestProgress = NSEntityDescription(class: LoggerNetworkRequestProgressEntity.self)
        let blob = NSEntityDescription(class: LoggerBlobHandleEntity.self)
        let inlinedData = NSEntityDescription(class: LoggerInlineDataEntity.self)
        let urlRequest = NSEntityDescription(class: NetworkRequestEntity.self)
        let httpHeader = NSEntityDescription(class: NetworkRequestHeaderEntity.self)

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
            NSAttributeDescription(name: "responseContentType", type: .stringAttributeType),
            NSAttributeDescription(name: "requestState", type: .integer16AttributeType),
            NSAttributeDescription(name: "redirectCount", type: .integer16AttributeType),
            NSAttributeDescription(name: "requestBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "responseBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "isFromCache", type: .booleanAttributeType),
            NSRelationshipDescription.make(name: "originalRequest", type: .oneToOne(), entity: urlRequest),
            NSRelationshipDescription.make(name: "currentRequest", type: .oneToOne(isOptional: true), entity: urlRequest),
            NSRelationshipDescription.make(name: "message", type: .oneToOne(), entity: message),
            NSRelationshipDescription.make(name: "detailsData", type: .oneToOne(), entity: inlinedData),
            NSRelationshipDescription.make(name: "requestBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            NSRelationshipDescription.make(name: "responseBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            NSRelationshipDescription.make(name: "progress", type: .oneToOne(isOptional: true), entity: requestProgress)
        ]

        urlRequest.properties = [
            NSAttributeDescription(name: "url", type: .stringAttributeType) { $0.isOptional = true },
            NSAttributeDescription(name: "httpMethod", type: .stringAttributeType) { $0.isOptional = true },
            NSRelationshipDescription.make(name: "httpHeaders", type: .oneToMany, entity: httpHeader),
            NSAttributeDescription(name: "allowsCellularAccess", type: .booleanAttributeType),
            NSAttributeDescription(name: "allowsExpensiveNetworkAccess", type: .booleanAttributeType),
            NSAttributeDescription(name: "allowsConstrainedNetworkAccess", type: .booleanAttributeType),
            NSAttributeDescription(name: "httpShouldHandleCookies", type: .booleanAttributeType),
            NSAttributeDescription(name: "httpShouldUsePipelining", type: .booleanAttributeType),
            NSAttributeDescription(name: "timeoutInterval", type: .doubleAttributeType),
            NSAttributeDescription(name: "rawCachePolicy", type: .integer16AttributeType)
        ]

        httpHeader.properties = [
            NSAttributeDescription(name: "name", type: .stringAttributeType),
            NSAttributeDescription(name: "value", type: .stringAttributeType)
        ]

        requestProgress.properties = [
            NSAttributeDescription(name: "completedUnitCount", type: .integer64AttributeType),
            NSAttributeDescription(name: "totalUnitCount", type: .integer64AttributeType)
        ]

        blob.properties = [
            NSAttributeDescription(name: "key", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "size", type: .integer32AttributeType),
            NSAttributeDescription(name: "decompressedSize", type: .integer32AttributeType),
            NSAttributeDescription(name: "linkCount", type: .integer16AttributeType),
            NSRelationshipDescription.make(name: "inlineData", type: .oneToOne(isOptional: true), entity: inlinedData)
        ]

        inlinedData.properties = [
            NSAttributeDescription(name: "data", type: .binaryDataAttributeType)
        ]

        model.entities = [message, metadata, request, requestProgress, blob, inlinedData, urlRequest, httpHeader]
        return model
    }()
}
