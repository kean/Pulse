// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Pulse
import Foundation

package struct FileViewerViewModelContext {
    package var contentType: NetworkLogger.ContentType?
    package var originalSize: Int64
    package var metadata: [String: String]?
    package var isResponse = true
    package var error: NetworkLogger.DecodingError?
    package var sourceURL: URL?

    package init(contentType: NetworkLogger.ContentType? = nil, originalSize: Int64, metadata: [String : String]? = nil, isResponse: Bool = true, error: NetworkLogger.DecodingError? = nil, sourceURL: URL? = nil) {
        self.contentType = contentType
        self.originalSize = originalSize
        self.metadata = metadata
        self.isResponse = isResponse
        self.error = error
        self.sourceURL = sourceURL
    }
}

extension NetworkTaskEntity {
    package var requestFileViewerContext: FileViewerViewModelContext {
        FileViewerViewModelContext(
            contentType: originalRequest?.contentType,
            originalSize: requestBodySize,
            metadata: metadata,
            isResponse: false,
            error: nil
        )
    }

    package var responseFileViewerContext: FileViewerViewModelContext {
        FileViewerViewModelContext(
            contentType: response?.contentType,
            originalSize: responseBodySize,
            metadata: metadata,
            isResponse: true,
            error: decodingError,
            sourceURL: currentRequest?.url.flatMap(URL.init)
        )
    }

    /// - returns `nil` if the task is an unknown state. It may happen if the
    /// task is pending, but it's from the previous app run.
    package func state(in store: LoggerStore?) -> NetworkTaskEntity.State? {
        let state = self.state
        if state == .pending, let store, self.session != store.session.id {
            return nil
        }
        return state
    }
}
