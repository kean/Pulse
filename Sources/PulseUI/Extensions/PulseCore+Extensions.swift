// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

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

    var responseCookies: [HTTPCookie] {
        guard let headers = response?.headers, !headers.isEmpty,
              let url = originalRequest?.url.flatMap(URL.init) else {
            return []
        }
        return HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
    }
}

extension NetworkRequestEntity {
    var cookies: [HTTPCookie] {
        guard !headers.isEmpty, let url = url.flatMap(URL.init) else {
            return []
        }
        return HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
    }
}
