// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

extension LoggerStore {
    /// Returns Core Data model used by the store.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        typealias Entity = NSEntityDescription
        typealias Attribute = NSAttributeDescription
        typealias Relationship = NSRelationshipDescription


        let message = Entity(class: LoggerMessageEntity.self)
        let metadata = Entity(class: LoggerMetadataEntity.self)
        let request = Entity(class: LoggerNetworkRequestEntity.self)
        let requestProgress = Entity(class: LoggerNetworkRequestProgressEntity.self)
        let blob = Entity(class: LoggerBlobHandleEntity.self)
        let inlinedData = Entity(class: LoggerInlineDataEntity.self)
        let urlRequest = Entity(class: NetworkRequestEntity.self)
        let urlResponse = Entity(class: NetworkResponseEntity.self)
        let error = Entity(class: NetworkErrorEntity.self)
        let metrics = Entity(class: NetworkMetricsEntity.self)
        let transactionMetrics = Entity(class: NetworkTransactionMetricsEntity.self)

        message.properties = [
            Attribute(name: "createdAt", type: .dateAttributeType),
            Attribute(name: "isPinned", type: .booleanAttributeType),
            Attribute(name: "session", type: .UUIDAttributeType),
            Attribute(name: "level", type: .integer16AttributeType),
            Attribute(name: "label", type: .stringAttributeType),
            Attribute(name: "text", type: .stringAttributeType),
            Relationship(name: "metadata", type: .oneToMany, entity: metadata),
            Attribute(name: "file", type: .stringAttributeType),
            Attribute(name: "function", type: .stringAttributeType),
            Attribute(name: "line", type: .integer32AttributeType),
            Relationship(name: "request", type: .oneToOne(isOptional: true), entity: request)
        ]

        metadata.properties = [
            Attribute(name: "key", type: .stringAttributeType),
            Attribute(name: "value", type: .stringAttributeType)
        ]

        request.properties = [
            Attribute(name: "createdAt", type: .dateAttributeType),
            Attribute(name: "isPinned", type: .booleanAttributeType),
            Attribute(name: "session", type: .UUIDAttributeType),
            Attribute(name: "taskId", type: .UUIDAttributeType),
            Attribute(name: "rawTaskType", type: .integer16AttributeType),
            Attribute(name: "url", type: .stringAttributeType),
            Attribute(name: "host", type: .stringAttributeType),
            Attribute(name: "httpMethod", type: .stringAttributeType),
            Attribute(name: "rawErrorDomain", type: .integer16AttributeType),
            Attribute(name: "errorCode", type: .integer32AttributeType),
            Attribute(name: "statusCode", type: .integer32AttributeType),
            Attribute(name: "duration", type: .doubleAttributeType),
            Attribute(name: "responseContentType", type: .stringAttributeType),
            Attribute(name: "requestState", type: .integer16AttributeType),
            Attribute(name: "requestBodySize", type: .integer64AttributeType),
            Attribute(name: "responseBodySize", type: .integer64AttributeType),
            Attribute(name: "isFromCache", type: .booleanAttributeType),
            Relationship(name: "originalRequest", type: .oneToOne(), entity: urlRequest),
            Relationship(name: "currentRequest", type: .oneToOne(isOptional: true), entity: urlRequest),
            Relationship(name: "response", type: .oneToOne(isOptional: true), entity: urlResponse),
            Relationship(name: "error", type: .oneToOne(isOptional: true), entity: error),
            Relationship(name: "metrics", type: .oneToOne(isOptional: true), entity: metrics),
            Relationship(name: "message", type: .oneToOne(), entity: message),
            Relationship(name: "rawMetadata", type: .oneToOne(), entity: inlinedData),
            Relationship(name: "requestBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            Relationship(name: "responseBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            Relationship(name: "progress", type: .oneToOne(isOptional: true), entity: requestProgress)
        ]

        urlRequest.properties = [
            Attribute(name: "url", type: .stringAttributeType) { $0.isOptional = true },
            Attribute(name: "httpMethod", type: .stringAttributeType) { $0.isOptional = true },
            Attribute(name: "httpHeaders", type: .stringAttributeType),
            Attribute(name: "allowsCellularAccess", type: .booleanAttributeType),
            Attribute(name: "allowsExpensiveNetworkAccess", type: .booleanAttributeType),
            Attribute(name: "allowsConstrainedNetworkAccess", type: .booleanAttributeType),
            Attribute(name: "httpShouldHandleCookies", type: .booleanAttributeType),
            Attribute(name: "httpShouldUsePipelining", type: .booleanAttributeType),
            Attribute(name: "timeoutInterval", type: .integer32AttributeType),
            Attribute(name: "rawCachePolicy", type: .integer16AttributeType)
        ]

        urlResponse.properties = [
            Attribute(name: "url", type: .stringAttributeType),
            Attribute(name: "statusCode", type: .integer16AttributeType),
            Attribute(name: "httpHeaders", type: .stringAttributeType),
        ]

        error.properties = [
            Attribute(name: "code", type: .integer32AttributeType),
            Attribute(name: "domain", type: .stringAttributeType),
            Attribute(name: "errorDebugDescription", type: .stringAttributeType),
            Attribute(name: "underlyingError", type: .binaryDataAttributeType)
        ]

        requestProgress.properties = [
            Attribute(name: "completedUnitCount", type: .integer64AttributeType),
            Attribute(name: "totalUnitCount", type: .integer64AttributeType)
        ]

        metrics.properties = [
            Attribute(name: "startDate", type: .dateAttributeType),
            Attribute(name: "duration", type: .doubleAttributeType),
            Attribute(name: "redirectCount", type: .integer16AttributeType),
            Relationship(name: "transactions", type: .oneToMany, entity: transactionMetrics)
        ]

        transactionMetrics.properties = [
            Attribute(name: "index", type: .integer16AttributeType),
            Attribute(name: "rawFetchType", type: .integer16AttributeType),
            Relationship(name: "request", type: .oneToOne(), entity: urlRequest),
            Relationship(name: "response", type: .oneToOne(isOptional: true), entity: urlResponse),
            Attribute(name: "networkProtocol", type: .stringAttributeType),
            Attribute(name: "localAddress", type: .stringAttributeType),
            Attribute(name: "remoteAddress", type: .stringAttributeType),
            Attribute(name: "localPort", type: .integer32AttributeType),
            Attribute(name: "remotePort", type: .integer32AttributeType),
            Attribute(name: "isProxyConnection", type: .booleanAttributeType),
            Attribute(name: "isReusedConnection", type: .booleanAttributeType),
            Attribute(name: "isCellular", type: .booleanAttributeType),
            Attribute(name: "isExpensive", type: .booleanAttributeType),
            Attribute(name: "isConstrained", type: .booleanAttributeType),
            Attribute(name: "isMultipath", type: .booleanAttributeType),
            Attribute(name: "rawNegotiatedTLSProtocolVersion", type: .integer16AttributeType),
            Attribute(name: "rawNegotiatedTLSCipherSuite", type: .integer16AttributeType),
            Attribute(name: "fetchStartDate", type: .dateAttributeType),
            Attribute(name: "domainLookupStartDate", type: .dateAttributeType),
            Attribute(name: "domainLookupEndDate", type: .dateAttributeType),
            Attribute(name: "connectStartDate", type: .dateAttributeType),
            Attribute(name: "secureConnectionStartDate", type: .dateAttributeType),
            Attribute(name: "secureConnectionEndDate", type: .dateAttributeType),
            Attribute(name: "connectEndDate", type: .dateAttributeType),
            Attribute(name: "requestStartDate", type: .dateAttributeType),
            Attribute(name: "requestEndDate", type: .dateAttributeType),
            Attribute(name: "responseStartDate", type: .dateAttributeType),
            Attribute(name: "responseEndDate", type: .dateAttributeType),
            Attribute(name: "requestHeaderBytesSent", type: .integer64AttributeType),
            Attribute(name: "requestBodyBytesBeforeEncoding", type: .integer64AttributeType),
            Attribute(name: "requestBodyBytesSent", type: .integer64AttributeType),
            Attribute(name: "responseHeaderBytesReceived", type: .integer64AttributeType),
            Attribute(name: "responseBodyBytesAfterDecoding", type: .integer64AttributeType),
            Attribute(name: "responseBodyBytesReceived", type: .integer64AttributeType)
        ]

        blob.properties = [
            Attribute(name: "key", type: .binaryDataAttributeType),
            Attribute(name: "size", type: .integer32AttributeType),
            Attribute(name: "decompressedSize", type: .integer32AttributeType),
            Attribute(name: "linkCount", type: .integer16AttributeType),
            Relationship(name: "inlineData", type: .oneToOne(isOptional: true), entity: inlinedData)
        ]

        inlinedData.properties = [
            Attribute(name: "data", type: .binaryDataAttributeType)
        ]

        model.entities = [message, metadata, request, requestProgress, blob, inlinedData, urlRequest, urlResponse, error, metrics, transactionMetrics]
        return model
    }()
}
