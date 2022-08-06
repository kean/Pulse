// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

// TODO: Add as extensions to LoggerNetworkRequestDetailsEntity?

#warning("TODO: remove this")
final class DecodedNetworkRequestDetailsEntity {
    private let request: LoggerNetworkRequestEntity
    private lazy var details = request.details

    private(set) lazy var originalRequest = details?.originalRequest
    private(set) lazy var currentRequest = details?.currentRequest
    private(set) lazy var response = details?.response
    private(set) lazy var error = details?.error
    private(set) lazy var metrics = details?.metrics
    private(set) lazy var metadata = details?.metadata

    init(request: LoggerNetworkRequestEntity) {
        self.request = request
    }

    var requestHeaders: [String: String] {
        currentRequest?.headers ?? originalRequest?.headers ?? [:]
    }

    var decodingError: NetworkLogger.DecodingError? {
        error?.error as? NetworkLogger.DecodingError
    }

    var requestFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: originalRequest?.contentType,
            originalSize: request.requestBodySize,
            metadata: metadata,
            isResponse: false,
            error: nil
        )
    }

    var responseFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: response?.contentType,
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
