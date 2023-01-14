// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

extension NetworkTaskEntity {
    var requestFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: originalRequest?.contentType,
            originalSize: requestBodySize,
            metadata: metadata,
            isResponse: false,
            error: nil
        )
    }

    var responseFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: response?.contentType,
            originalSize: responseBodySize,
            metadata: metadata,
            isResponse: true,
            error: decodingError
        )
    }
}

extension LoggerMessageEntity {
    var logLevel: LoggerStore.Level {
        LoggerStore.Level(rawValue: level) ?? .debug
    }
}

/// A thread-safe non-CoreData variant of `NetworkTaskEntity`.
final class NetworkTask {
    // Summary
    let url: URL?
    let rawURL: String?
    let httpMethod: String
    let taskType: NetworkLogger.TaskType
    let state: NetworkTaskEntity.State
    let createdAt: Date

    // Details
    let originalRequest: NetworkLogger.Request?
    let currentRequest: NetworkLogger.Request?
    let response: NetworkLogger.Response?
    let error: NetworkLogger.ResponseError?
    let requestBodySize: Int64
    let requestBody: Data?
    let responseBodySize: Int64
    let responseBody: Data?

#warning("TODO: read lazily")
#warning("TODO: check if error is read corrency")
    init(_ entity: NetworkTaskEntity, content: NetworkContent = [.all]) {
        self.url = entity.url.flatMap(URL.init)
        self.rawURL = entity.url
        self.httpMethod = entity.httpMethod ?? "GET"
        self.taskType = entity.type ?? .dataTask
        self.createdAt = entity.createdAt
        self.state = entity.state
        self.originalRequest = entity.originalRequest.map(NetworkLogger.Request.init)
        self.currentRequest = entity.currentRequest.map(NetworkLogger.Request.init)
        self.response = entity.response.map(NetworkLogger.Response.init)
        self.error = entity.error.map(NetworkLogger.ResponseError.init)
        self.requestBodySize = entity.requestBodySize
        self.requestBody = entity.requestBody?.data
        self.responseBodySize = entity.responseBodySize
        self.responseBody = entity.responseBody?.data
    }
}
