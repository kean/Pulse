// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

final class NetworkLoggerSummary {
    private let objectId: NSManagedObjectID?
    let request: NetworkLoggerRequest?
    let response: NetworkLoggerResponse?
    let error: NetworkLoggerError?
    let metrics: NetworkLoggerMetrics?
    let session: NetworkLoggerURLSession?

    let requestBodyKey: String?
    let responseBodyKey: String?
    let requestBodySize: Int64
    let responseBodySize: Int64

    private(set) lazy var requestBody: Data? = requestBodyKey.flatMap(store.getData)
    private(set) lazy var responseBody: Data? = responseBodyKey.flatMap(store.getData)

    private let store: LoggerStore

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        let details = request.details
        self.request = details.request.flatMap(decode(NetworkLoggerRequest.self))
        self.response = details.response.flatMap(decode(NetworkLoggerResponse.self))
        self.error = details.error.flatMap(decode(NetworkLoggerError.self))
        self.metrics = details.metrics.flatMap(decode(NetworkLoggerMetrics.self))
        self.session = details.urlSession.flatMap(decode(NetworkLoggerURLSession.self))
        self.requestBodyKey = request.requestBodyKey
        self.requestBodySize = details.requestBodySize
        self.responseBodyKey = request.responseBodyKey
        self.responseBodySize = details.responseBodySize
        self.objectId = request.objectID

        self.store = store
    }
}

private func decode<T: Decodable>(_ type: T.Type) -> (_ data: Data?) -> T? {
    {
        guard let data = $0 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
