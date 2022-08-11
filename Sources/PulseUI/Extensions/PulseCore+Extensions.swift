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

        for header in request.httpHeaders {
            let escapedValue = header.value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(header.name): \(escapedValue)\"")
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
            metadata: details?.metadata,
            isResponse: false,
            error: nil
        )
    }

    var responseFileViewerContext: FileViewerViewModel.Context {
        FileViewerViewModel.Context(
            contentType: details?.response?.contentType,
            originalSize: responseBodySize,
            metadata: details?.metadata,
            isResponse: true,
            error: details?.decodingError
        )
    }
}

extension LoggerNetworkRequestEntity.RequestDetails {
    var decodingError: NetworkLogger.DecodingError? {
        error?.error as? NetworkLogger.DecodingError
    }
}
