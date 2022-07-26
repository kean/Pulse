// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import PulseCore
import Foundation

extension LoggerNetworkRequestEntity {
    func cURLDescription(store: LoggerStore) -> String {
        let details = DecodedNetworkRequestDetailsEntity(request: self)
        guard let request = details.currentRequest, let url = request.url, let method = request.httpMethod else {
            return "$ curl command generation failed"
        }

        var components = ["curl -v"]

        components.append("-X \(method)")

        for header in request.headers {
            let escapedValue = header.value.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-H \"\(header.key): \(escapedValue)\"")
        }

        if let httpBodyData = requestBodyKey.flatMap(store.getData) {
            let httpBody = String(decoding: httpBodyData, as: UTF8.self)
            var escapedBody = httpBody.replacingOccurrences(of: "\\\"", with: "\\\\\"")
            escapedBody = escapedBody.replacingOccurrences(of: "\"", with: "\\\"")
            components.append("-d \"\(escapedBody)\"")
        }

        components.append("\"\(url.absoluteString)\"")

        return components.joined(separator: " \\\n\t")
    }
}
