// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

#if os(iOS) || os(macOS)

extension LoggerNetworkRequestEntity {
    func cURLDescription() -> String {
        let request = currentRequest ?? originalRequest
        guard let url = request.url else {
            return "$ curl command generation failed"
        }

        var components = ["curl -v"]

        components.append("-X \(request.httpMethod ?? "GET")")

        for header in request.headers {
            let escapedValue = header.value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(header.key): \(escapedValue)\"")
        }

        if let httpBodyData = requestBody?.data {
            let httpBody = String(decoding: httpBodyData, as: UTF8.self)
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(url)\"")

        return components.joined(separator: " \\\n\t")
    }
}

#endif

extension LoggerNetworkRequestEntity {
    var requestFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: originalRequest.contentType,
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

extension LoggerNetworkRequestEntity {
    var decodingError: NetworkLogger.DecodingError? {
        error?.error as? NetworkLogger.DecodingError
    }
}
