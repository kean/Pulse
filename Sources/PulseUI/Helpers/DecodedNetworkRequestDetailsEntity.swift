// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

// TODO: Add as extensions to LoggerNetworkRequestDetailsEntity?
final class DecodedNetworkRequestDetailsEntity {
    private let request: LoggerNetworkRequestEntity
    private let details: LoggerNetworkRequestDetailsEntity

    private(set) lazy var originalRequest = decode(NetworkLogger.Request.self, from: details.originalRequest)
    private(set) lazy var currentRequest = decode(NetworkLogger.Request.self, from: details.currentRequest)
    private(set) lazy var response = decode(NetworkLogger.Response.self, from: details.response)
    private(set) lazy var error = decode(NetworkLogger.ResponseError.self, from: details.error)
    private(set) lazy var metrics = decode(NetworkLogger.Metrics.self, from: details.metrics)
    private(set) lazy var metadata = decode([String: String].self, from: details.metadata)

    init(request: LoggerNetworkRequestEntity) {
        self.request = request
        self.details = request.details
    }

    var requestHeaders: [String: String] {
        currentRequest?.headers ?? originalRequest?.headers ?? [:]
    }

    var requestContentType: NetworkLogger.ContentType? {
        requestHeaders["Content-Type"].flatMap(NetworkLogger.ContentType.init)
    }

    var decodingError: NetworkLogger.DecodingError? {
        error?.error as? NetworkLogger.DecodingError
    }

    var requestFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: requestContentType,
            originalSize: request.requestBodySize,
            metadata: metadata,
            isResponse: false,
            error: nil
        )
    }

    var responseFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: request.contentType.flatMap(NetworkLogger.ContentType.init),
            originalSize: request.responseBodySize,
            metadata: metadata,
            isResponse: true,
            error: decodingError
        )
    }
}

extension LoggerNetworkRequestEntity {
    var metrics: NetworkLogger.Metrics? {
        DecodedNetworkRequestDetailsEntity(request: self).metrics
    }
}

private func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
    data.flatMap { try? JSONDecoder().decode(type, from: $0) }
}
