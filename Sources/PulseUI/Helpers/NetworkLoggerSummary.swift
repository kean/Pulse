// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

#warning("remove")
final class NetworkLoggerSummary {
    private let objectId: NSManagedObjectID?
    let taskType: NetworkLoggerTaskType?
    let originalRequest: NetworkLoggerRequest?
    let currentRequest: NetworkLoggerRequest?
    let state: LoggerNetworkRequestEntity.State
    let response: NetworkLoggerResponse?
    let error: NetworkLoggerError?
    let metrics: NetworkLoggerMetrics?

    let requestBodyKey: String?
    let responseBodyKey: String?
    let requestBodySize: Int64
    let responseBodySize: Int64
    let isFromCache: Bool

    #warning("remove")
    let progress: ProgressViewModel

    private(set) lazy var requestBody: Data? = requestBodyKey.flatMap(store.getData)
    private(set) lazy var responseBody: Data? = responseBodyKey.flatMap(store.getData)

#warning("remove")
    let store: LoggerStore
    let request: LoggerNetworkRequestEntity

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.request = request
        let details = request.details
        self.taskType = request.taskType
        self.originalRequest = details.originalRequest.flatMap(decode(NetworkLoggerRequest.self))
        self.currentRequest = details.currentRequest.flatMap(decode(NetworkLoggerRequest.self))
        self.state = request.state
        self.response = details.response.flatMap(decode(NetworkLoggerResponse.self))
        self.error = details.error.flatMap(decode(NetworkLoggerError.self))
        self.metrics = details.metrics.flatMap(decode(NetworkLoggerMetrics.self))
        self.requestBodyKey = request.requestBodyKey
        self.requestBodySize = request.requestBodySize
        self.responseBodyKey = request.responseBodyKey
        self.responseBodySize = request.responseBodySize
        self.isFromCache = request.isFromCache
        self.objectId = request.objectID
        self.progress = ProgressViewModel(request: request)

        self.store = store
    }
}

private func decode<T: Decodable>(_ type: T.Type) -> (_ data: Data?) -> T? {
    {
        guard let data = $0 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
    data.flatMap { try? JSONDecoder().decode(type, from: $0) }
}

final class DecodedNetworkRequestDetailsEntity {
    private let details: LoggerNetworkRequestDetailsEntity

    private(set) lazy var originalRequest = decode(NetworkLoggerRequest.self, from: details.originalRequest)
    private(set) lazy var currentRequest = decode(NetworkLoggerRequest.self, from: details.currentRequest)
    private(set) lazy var response = decode(NetworkLoggerResponse.self, from: details.response)
    private(set) lazy var error = decode(NetworkLoggerError.self, from: details.error)
    private(set) lazy var metrics = decode(NetworkLoggerMetrics.self, from: details.metrics)
    private(set) lazy var lastTransactionDetails = decode(NetworkLoggerTransactionDetailedMetrics.self, from: details.lastTransactionDetails)

    init(request: LoggerNetworkRequestEntity) {
        self.details = request.details
    }
}
