// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if !os(macOS) && !targetEnvironment(macCatalyst) && swift(>=5.7)
import Foundation
#else
@preconcurrency import Foundation
#endif

// MARK: - Redacting Sensitive Headers

extension NetworkLogger.Request {
    /// Redacts values for the provided headers.
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
    /// Redacts values for the provided headers.
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

extension NetworkLogger.Metrics {
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

// MARK: - Redacting Sensitive Data Fields

extension Data {
    func redactingSensitiveFields(_ fields: Set<String>) -> Data {
        guard let json = try? JSONSerialization.jsonObject(with: self)  else {
            return self
        }
        let redacted = Pulse.redactingSensitiveFields(json, fields)
        return (try? JSONSerialization.data(withJSONObject: redacted)) ?? self
    }
}

func redactingSensitiveFields(_ value: Any, _ fields: Set<String>) -> Any {
    switch value {
    case var object as [String: Any]:
        for key in object.keys.filter(fields.contains) {
            object[key] = "<private>"
        }
        return object
    case let array as [Any]:
        return array.map { _ in redactingSensitiveFields(array, fields) }
    default:
        return value
    }
}
