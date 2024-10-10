// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import CoreData

extension LoggerStore {
    /// Returns Core Data model used by the store.
    /// 
    /// - warning: Model has to be loaded only once.
    nonisolated(unsafe) package static let model: NSManagedObjectModel = {
        typealias Entity = NSEntityDescription
        typealias Attribute = NSAttributeDescription
        typealias Relationship = NSRelationshipDescription

        let session = Entity(class: LoggerSessionEntity.self)
        let message = Entity(class: LoggerMessageEntity.self)
        let task = Entity(class: NetworkTaskEntity.self)
        let progress = Entity(class: NetworkTaskProgressEntity.self)
        let request = Entity(class: NetworkRequestEntity.self)
        let response = Entity(class: NetworkResponseEntity.self)
        let transaction = Entity(class: NetworkTransactionMetricsEntity.self)
        let blob = Entity(class: LoggerBlobHandleEntity.self)

        session.properties = [
            Attribute("id", .UUIDAttributeType),
            Attribute("createdAt", .dateAttributeType),
            Attribute("version", .stringAttributeType) { $0.isOptional = true },
            Attribute("build", .stringAttributeType) { $0.isOptional = true }
        ]

        message.properties = [
            Attribute("createdAt", .dateAttributeType),
            Attribute("isPinned", .booleanAttributeType),
            Attribute("session", .UUIDAttributeType),
            Attribute("level", .integer16AttributeType),
            Attribute("text", .stringAttributeType),
            Attribute("file", .stringAttributeType),
            Attribute("function", .stringAttributeType),
            Attribute("line", .integer32AttributeType),
            Attribute("rawMetadata", .stringAttributeType),
            Attribute("label", .stringAttributeType),
            Relationship("task", .oneToOne(isOptional: true), entity: task)
        ]

        task.properties = [
            Attribute("createdAt", .dateAttributeType),
            Attribute("isPinned", .booleanAttributeType),
            Attribute("session", .UUIDAttributeType),
            Attribute("taskId", .UUIDAttributeType),
            Attribute("taskType", .integer16AttributeType),
            Attribute("url", .stringAttributeType),
            Attribute("host", .stringAttributeType),
            Attribute("httpMethod", .stringAttributeType),
            Attribute("statusCode", .integer32AttributeType),
            Attribute("errorCode", .integer32AttributeType),
            Attribute("errorDomain", .stringAttributeType),
            Attribute("errorDebugDescription", .stringAttributeType),
            Attribute("underlyingError", .binaryDataAttributeType),
            Attribute("startDate", .dateAttributeType),
            Attribute("duration", .doubleAttributeType),
            Attribute("redirectCount", .integer16AttributeType),
            Attribute("responseContentType", .stringAttributeType),
            Attribute("requestState", .integer16AttributeType),
            Attribute("requestBodySize", .integer64AttributeType),
            Attribute("responseBodySize", .integer64AttributeType),
            Attribute("isFromCache", .booleanAttributeType),
            Attribute("isMocked", .booleanAttributeType),
            Attribute("rawMetadata", .stringAttributeType),
            Attribute("taskDescription", .stringAttributeType),
            Relationship("originalRequest", .oneToOne(), entity: request),
            Relationship("currentRequest", .oneToOne(isOptional: true), entity: request),
            Relationship("response", .oneToOne(isOptional: true), entity: response),
            Relationship("transactions", .oneToMany, entity: transaction),
            Relationship("message", .oneToOne(), entity: message),
            Relationship("requestBody", .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            Relationship("responseBody", .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            Relationship("progress", .oneToOne(isOptional: true), entity: progress)
        ]

        request.properties = [
            Attribute("url", .stringAttributeType),
            Attribute("httpMethod", .stringAttributeType) { $0.isOptional = true },
            Attribute("httpHeaders", .stringAttributeType),
            Attribute("allowsCellularAccess", .booleanAttributeType),
            Attribute("allowsExpensiveNetworkAccess", .booleanAttributeType),
            Attribute("allowsConstrainedNetworkAccess", .booleanAttributeType),
            Attribute("httpShouldHandleCookies", .booleanAttributeType),
            Attribute("httpShouldUsePipelining", .booleanAttributeType),
            Attribute("timeoutInterval", .integer32AttributeType),
            Attribute("rawCachePolicy", .integer16AttributeType)
        ]

        response.properties = [
            Attribute("statusCode", .integer16AttributeType),
            Attribute("httpHeaders", .stringAttributeType)
        ]

        progress.properties = [
            Attribute("completedUnitCount", .integer64AttributeType),
            Attribute("totalUnitCount", .integer64AttributeType)
        ]

        transaction.properties = [
            Attribute("index", .integer16AttributeType),
            Attribute("rawFetchType", .integer16AttributeType),
            Relationship("request", .oneToOne(), entity: request),
            Relationship("response", .oneToOne(isOptional: true), entity: response),
            Attribute("networkProtocol", .stringAttributeType),
            Attribute("localAddress", .stringAttributeType),
            Attribute("remoteAddress", .stringAttributeType),
            Attribute("localPort", .integer32AttributeType),
            Attribute("remotePort", .integer32AttributeType),
            Attribute("isProxyConnection", .booleanAttributeType),
            Attribute("isReusedConnection", .booleanAttributeType),
            Attribute("isCellular", .booleanAttributeType),
            Attribute("isExpensive", .booleanAttributeType),
            Attribute("isConstrained", .booleanAttributeType),
            Attribute("isMultipath", .booleanAttributeType),
            Attribute("rawNegotiatedTLSProtocolVersion", .integer32AttributeType),
            Attribute("rawNegotiatedTLSCipherSuite", .integer32AttributeType),
            Attribute("fetchStartDate", .dateAttributeType),
            Attribute("domainLookupStartDate", .dateAttributeType),
            Attribute("domainLookupEndDate", .dateAttributeType),
            Attribute("connectStartDate", .dateAttributeType),
            Attribute("secureConnectionStartDate", .dateAttributeType),
            Attribute("secureConnectionEndDate", .dateAttributeType),
            Attribute("connectEndDate", .dateAttributeType),
            Attribute("requestStartDate", .dateAttributeType),
            Attribute("requestEndDate", .dateAttributeType),
            Attribute("responseStartDate", .dateAttributeType),
            Attribute("responseEndDate", .dateAttributeType),
            Attribute("requestHeaderBytesSent", .integer64AttributeType),
            Attribute("requestBodyBytesBeforeEncoding", .integer64AttributeType),
            Attribute("requestBodyBytesSent", .integer64AttributeType),
            Attribute("responseHeaderBytesReceived", .integer64AttributeType),
            Attribute("responseBodyBytesAfterDecoding", .integer64AttributeType),
            Attribute("responseBodyBytesReceived", .integer64AttributeType)
        ]

        blob.properties = [
            Attribute("key", .binaryDataAttributeType),
            Attribute("size", .integer32AttributeType),
            Attribute("decompressedSize", .integer32AttributeType),
            Attribute("linkCount", .integer32AttributeType),
            Attribute("rawContentType", .stringAttributeType),
            Attribute("inlineData", .binaryDataAttributeType),
            Attribute("isUncompressed", .booleanAttributeType)
        ]

        let model = NSManagedObjectModel()
        model.entities = [session, message, task, progress, blob, request, response, transaction]
        return model
    }()
}
