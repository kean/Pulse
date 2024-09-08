// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Pulse
import Foundation

struct FileViewerViewModelContext {
    var contentType: NetworkLogger.ContentType?
    var originalSize: Int64
    var metadata: [String: String]?
    var isResponse = true
    var error: NetworkLogger.DecodingError?
    var sourceURL: URL?
}

extension NetworkTaskEntity {
    var requestFileViewerContext: FileViewerViewModelContext {
        FileViewerViewModelContext(
            contentType: originalRequest?.contentType,
            originalSize: requestBodySize,
            metadata: metadata,
            isResponse: false,
            error: nil
        )
    }

    var responseFileViewerContext: FileViewerViewModelContext {
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
    func state(in store: LoggerStore?) -> NetworkTaskEntity.State? {
        let state = self.state
        if state == .pending, let store, self.session != store.session.id {
            return nil
        }
        return state
    }
}
