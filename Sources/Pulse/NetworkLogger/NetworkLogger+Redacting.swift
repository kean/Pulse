// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - Redacting Sensitive Headers

extension LoggerStore.Event {
    func redactingSensitiveHeaders(_ excludedHeaders: [Regex]) -> Self {
        guard !excludedHeaders.isEmpty else {
            return self
        }
        switch self {
        case .messageStored, .networkTaskProgressUpdated:
            return self
        case .networkTaskCreated(let event):
            var event = event
            event.originalRequest = event.originalRequest.redactingSensitiveHeaders(excludedHeaders)
            event.currentRequest = event.currentRequest?.redactingSensitiveHeaders(excludedHeaders)
            return .networkTaskCreated(event)
        case .networkTaskCompleted(let event):
            var event = event
            event.originalRequest = event.originalRequest.redactingSensitiveHeaders(excludedHeaders)
            event.currentRequest = event.currentRequest?.redactingSensitiveHeaders(excludedHeaders)
            event.response = event.response?.redactingSensitiveHeaders(excludedHeaders)
            event.metrics = event.metrics?.redactingSensitiveHeaders(excludedHeaders)
            return .networkTaskCompleted(event)
        }
    }

    func redactingSensitiveQueryItems(_ excludedQueryItems: Set<String>) -> Self {
        guard !excludedQueryItems.isEmpty else {
            return self
        }
        switch self {
        case .messageStored, .networkTaskProgressUpdated:
            return self
        case .networkTaskCreated(let event):
            var event = event
            event.originalRequest = event.originalRequest.redactingSensitiveQueryItems(excludedQueryItems)
            event.currentRequest = event.currentRequest?.redactingSensitiveQueryItems(excludedQueryItems)
            return .networkTaskCreated(event)
        case .networkTaskCompleted(let event):
            var event = event
            event.originalRequest = event.originalRequest.redactingSensitiveQueryItems(excludedQueryItems)
            event.currentRequest = event.currentRequest?.redactingSensitiveQueryItems(excludedQueryItems)
            event.metrics = event.metrics?.redactingSensitiveQueryItems(excludedQueryItems)
            return .networkTaskCompleted(event)
        }
    }

    func redactingSensitiveResponseDataFields(_ excludedDataFields: Set<String>) -> LoggerStore.Event {
        guard !excludedDataFields.isEmpty else {
            return self
        }
        switch self {
        case .messageStored, .networkTaskProgressUpdated, .networkTaskCreated:
            return self
        case .networkTaskCompleted(let event):
            var event = event
            event.requestBody = event.requestBody?.redactingSensitiveFields(excludedDataFields)
            event.responseBody = event.responseBody?.redactingSensitiveFields(excludedDataFields)
            return .networkTaskCompleted(event)
        }
    }
}

// MARK: - Redacting Headers

extension NetworkLogger.Request {
    /// Soft-deprecated in Pulse 3.0
    public func redactingSensitiveHeaders(_ redactedHeaders: Set<String>) -> Self {
        var copy = self
        copy.headers = _redactingSensitiveHeaders(redactedHeaders, from: headers)
        return copy
    }

    func redactingSensitiveHeaders(_ redactedHeaders: [Regex]) -> Self {
        var copy = self
        copy.headers = _redactingSensitiveHeaders(redactedHeaders, from: headers)
        return copy
    }
}

extension NetworkLogger.Response {
    /// Soft-deprecated in Pulse 3.0
    public func redactingSensitiveHeaders(_ redactedHeaders: Set<String>) -> Self {
        var copy = self
        copy.headers = _redactingSensitiveHeaders(redactedHeaders, from: headers)
        return copy
    }

    func redactingSensitiveHeaders(_ redactedHeaders: [Regex]) -> Self {
        var copy = self
        copy.headers = _redactingSensitiveHeaders(redactedHeaders, from: headers)
        return copy
    }
}

private extension NetworkLogger.Metrics {
    func redactingSensitiveHeaders(_ redactedHeaders: [Regex]) -> Self {
        var copy = self
        copy.transactions = transactions.map {
            var transaction = $0
            transaction.request = transaction.request.redactingSensitiveHeaders(redactedHeaders)
            transaction.response = transaction.response?.redactingSensitiveHeaders(redactedHeaders)
            return transaction
        }
        return copy
    }
}

private func _redactingSensitiveHeaders(_ redactedHeaders: Set<String>, from headers: [String: String]?) -> [String: String]? {
    guard let headers = headers else {
        return nil
    }
    var newHeaders: [String: String] = [:]
    let redactedHeaders = Set(redactedHeaders.map { $0.lowercased() })
    for (key, value) in headers {
        if redactedHeaders.contains(key.lowercased()) {
            newHeaders[key] = "<private>"
        } else {
            newHeaders[key] = value
        }
    }
    return newHeaders
}

private func _redactingSensitiveHeaders(_ redactedHeaders: [Regex], from headers: [String: String]?) -> [String: String]? {
    guard let headers = headers else {
        return nil
    }
    let redacted = headers.keys.filter { header in
        redactedHeaders.contains { $0.isMatch(header) }
    }
    return _redactingSensitiveHeaders(Set(redacted), from: headers)
}

// MARK: - Redacting Query Items

private extension NetworkLogger.Request {
    func redactingSensitiveQueryItems(_ redactedQueryItems: Set<String>) -> Self {
        var copy = self
        copy.url = url?.redactingSensitiveQueryItems(redactedQueryItems)
        return copy
    }
}

private extension NetworkLogger.Metrics {
    func redactingSensitiveQueryItems(_ redactedQueryItems: Set<String>) -> Self {
        var copy = self
        copy.transactions = transactions.map {
            var transaction = $0
            transaction.request = transaction.request.redactingSensitiveQueryItems(redactedQueryItems)
            return transaction
        }
        return copy
    }
}

private extension URL {
    func redactingSensitiveQueryItems(_ redactedQueryItems: Set<String>) -> Self {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = components.queryItems?.map {
            var item = $0
            if redactedQueryItems.contains($0.name.lowercased()) {
                item.value = "private"
            }
            return item
        }
        return components.url ?? self
    }
}

// MARK: - Redacting Data Fields

private extension Data {
    func redactingSensitiveFields(_ fields: Set<String>) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: self)  else {
            return self
        }
        let redacted = _redactingSensitiveFields(json, fields)
        return (try? JSONSerialization.data(withJSONObject: redacted)) ?? self
    }
}

private func _redactingSensitiveFields(_ value: Any, _ fields: Set<String>) -> Any {
    switch value {
    case var object as [String: Any]:
        for key in object.keys.filter(fields.contains) {
            object[key] = "<private>"
        }
        return object
    case let array as [Any]:
        return array.map { _redactingSensitiveFields($0, fields) }
    default:
        return value
    }
}
