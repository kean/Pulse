// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

// TODO: Add as extensions to LoggerNetworkRequestDetailsEntity?
final class DecodedNetworkRequestDetailsEntity {
    private let details: LoggerNetworkRequestDetailsEntity

    private(set) lazy var originalRequest = decode(NetworkLoggerRequest.self, from: details.originalRequest)
    private(set) lazy var currentRequest = decode(NetworkLoggerRequest.self, from: details.currentRequest)
    private(set) lazy var response = decode(NetworkLoggerResponse.self, from: details.response)
    private(set) lazy var error = decode(NetworkLoggerError.self, from: details.error)
    private(set) lazy var metrics = decode(NetworkLoggerMetrics.self, from: details.metrics)

    init(request: LoggerNetworkRequestEntity) {
        self.details = request.details
    }
}

extension LoggerNetworkRequestEntity {
    var metrics: NetworkLoggerMetrics? {
        DecodedNetworkRequestDetailsEntity(request: self).metrics
    }
}

private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
    data.flatMap { try? JSONDecoder().decode(type, from: $0) }
}
