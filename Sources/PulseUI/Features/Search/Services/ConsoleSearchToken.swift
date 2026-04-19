// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import Pulse

package enum ConsoleSearchToken: Hashable {
    // Logs
    case level(LoggerStore.Level)
    case label(String)

    // Network
    case host(String)
    case method(HTTPMethod)
    case path(String)
    case statusCode(String)

    package var name: String {
        switch self {
        case .level: return "Level"
        case .label: return "Label"
        case .host: return "Host"
        case .method: return "Method"
        case .path: return "Path"
        case .statusCode: return "Status Code"
        }
    }

    package var valueDescription: String {
        switch self {
        case .level(let level): return level.name
        case .label(let value): return value
        case .host(let value): return value
        case .method(let method): return method.rawValue
        case .path(let value): return value
        case .statusCode(let value): return value
        }
    }

    package var systemImage: String {
        switch self {
        case .level: return "flag"
        case .label: return "tag"
        case .host: return "server.rack"
        case .method: return "arrow.up.arrow.down"
        case .path: return "slash.circle"
        case .statusCode: return "number"
        }
    }

    /// Creates a draft ``ConsoleCustomFilter`` if this token can be represented as one.
    package func makeCustomFilter() -> ConsoleCustomFilter? {
        switch self {
        case .label(let value):
            return ConsoleCustomFilter(field: .label, match: defaultMatch, value: value)
        case .host(let value):
            return ConsoleCustomFilter(field: .host, match: defaultMatch, value: value)
        case .path(let value):
            return ConsoleCustomFilter(field: .path, value: value)
        case .method(let method):
            return ConsoleCustomFilter(field: .method, match: .init(rule: .equal), value: method.rawValue)
        default:
            return nil
        }
    }

    package func apply(to criteria: inout ConsoleFilters, filter: ConsoleCustomFilter? = nil) {
        switch self {
        case .level(let level):
            criteria.messages.logLevels.isEnabled = true
            criteria.messages.logLevels.levels = [level]
        case .label(let label):
            guard let filter = filter ?? makeCustomFilter() else { return }
            if filter.match.rule == .equal {
                criteria.messages.labels.isEnabled = true
                criteria.messages.labels.focused = label
            } else {
                criteria.messages.custom.isEnabled = true
                criteria.messages.custom.filters = [filter]
            }
        case .host(let host):
            guard let filter = filter ?? makeCustomFilter() else { return }
            if filter.match.rule == .equal {
                criteria.network.host.isEnabled = true
                criteria.network.host.focused = host
            } else {
                criteria.network.custom.isEnabled = true
                criteria.network.custom.filters = [filter]
            }
        case .method, .path:
            guard let filter = filter ?? makeCustomFilter() else { return }
            criteria.network.custom.isEnabled = true
            criteria.network.custom.filters = [filter]
        case .statusCode(let code):
            criteria.network.response.isEnabled = true
            criteria.network.response.statusCode.range = ConsoleSearchToken.parseStatusCodeRange(code)
        }
    }

    package var defaultMatch: StringSearchOptions {
        switch self {
        case .host, .label, .path: return .init(rule: .equal)
        default: return .default
        }
    }
    /// Parses a status code description (e.g. "200", "2XX", "200..<300")
    /// into a `ValuesRange` suitable for `ConsoleFilters.StatusCode`.
    package static func parseStatusCodeRange(_ code: String) -> ValuesRange<String> {
        // Take only the first token (ignore comma-separated values for range)
        let token = code.split(separator: ",").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? code

        // Half-open range: "200..<300"
        if let range = token.range(of: "..<") {
            let lower = String(token[token.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let upper = String(token[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if let upperInt = Int(upper) {
                return ValuesRange(lowerBound: lower, upperBound: "\(upperInt - 1)")
            }
        }

        // Closed range: "200...300"
        if let range = token.range(of: "...") {
            let lower = String(token[token.startIndex..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let upper = String(token[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            return ValuesRange(lowerBound: lower, upperBound: upper)
        }

        // Wildcard: "2XX" → 200...299, "4XX" → 400...499
        if token.count == 3, let digit = token.first, digit.isNumber,
           token.dropFirst().allSatisfy({ "xX*".contains($0) }) {
            let base = Int(String(digit))! * 100
            return ValuesRange(lowerBound: "\(base)", upperBound: "\(base + 99)")
        }

        // Exact value: "200" → 200...200
        if Int(token) != nil {
            return ValuesRange(lowerBound: token, upperBound: token)
        }

        return .empty
    }
}

// MARK: - Confidence

package struct Confidence: Hashable, Comparable, ExpressibleByFloatLiteral {
    package let rawValue: Float

    package init(floatLiteral value: FloatLiteralType) {
        self.rawValue = max(0, min(1, Float(value)))
    }

    package init(_ rawValue: Float) {
        self.rawValue = max(0, min(1, rawValue))
    }

    package static func < (lhs: Confidence, rhs: Confidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Substring Matching

extension String {
    package static func substringMatch(searchText: String, from source: Set<String>) -> [(String, Confidence)] {
        guard !searchText.isEmpty else { return [] }
        let lower = searchText.lowercased()
        var results: [(String, Confidence)] = []
        for value in source {
            let valueLower = value.lowercased()
            if valueLower == lower {
                results.append((value, Confidence(1.0)))
            } else if valueLower.hasPrefix(lower) {
                results.append((value, Confidence(0.9)))
            } else if valueLower.contains(lower) {
                results.append((value, Confidence(0.8)))
            }
        }
        return Array(results.sorted(by: { $0.1 > $1.1 }).prefix(2))
    }
}

#endif
