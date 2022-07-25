// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

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

    private let store: LoggerStore

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
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
