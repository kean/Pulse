// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import Pulse

package struct ConsoleSearchFilterMatcher {
    package static func suggestions(
        for searchText: String,
        index: LoggerStoreIndex,
        mode: ConsoleMode,
        hasLogFilters: Bool,
        hasNetworkFilters: Bool
    ) -> [(ConsoleSearchToken, Confidence)] {
        guard !searchText.isEmpty else { return [] }
        var results: [(ConsoleSearchToken, Confidence)] = []
        if mode.hasLogs && !hasNetworkFilters {
            results += substringMatch(searchText, in: levelNames) { .level(levelMap[$0]!) }
            results += substringMatch(searchText, in: index.labels) { .label($0) }
        }
        if mode.hasNetwork && !hasLogFilters {
            results += matchStatusCodes(searchText)
            results += substringMatch(searchText, in: index.hosts) { .host($0) }
            results += substringMatch(searchText, in: index.paths) { .path($0) }
            results += matchMethods(searchText)
        }
        return results
    }

    private static let levelMap = Dictionary(uniqueKeysWithValues: LoggerStore.Level.allCases.map { ($0.name, $0) })
    private static let levelNames = Set(LoggerStore.Level.allCases.map(\.name))

    private static func substringMatch(
        _ searchText: String,
        in values: Set<String>,
        makeFilter: (String) -> ConsoleSearchToken
    ) -> [(ConsoleSearchToken, Confidence)] {
        String.substringMatch(searchText: searchText, from: values).map { (makeFilter($0.0), $0.1) }
    }

    // MARK: - HTTP Methods (exact, case-insensitive)

    package static func matchMethods(_ searchText: String) -> [(ConsoleSearchToken, Confidence)] {
        let upper = searchText.uppercased()
        return HTTPMethod.allCases.compactMap { method in
            if method.rawValue == upper {
                return (.method(method), Confidence(1.0))
            }
            if upper.count >= 2, method.rawValue.hasPrefix(upper) {
                return (.method(method), Confidence(0.8))
            }
            return nil
        }
    }

    // MARK: - Status Codes

    private static func matchStatusCodes(_ searchText: String) -> [(ConsoleSearchToken, Confidence)] {
        let tokens = searchText.split(separator: ",")
            .flatMap { $0.split(separator: " ") }
            .map(String.init)
        let descriptions = tokens.compactMap { parseStatusCodeDescription($0) }
        guard !descriptions.isEmpty else { return [] }
        return [(.statusCode(descriptions.joined(separator: ", ")), Confidence(0.8))]
    }

    /// Parses a status code token and returns a display description, or nil if invalid.
    package static func parseStatusCodeDescription(_ token: String) -> String? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Try Swift range patterns: "200..<300", "200...300"
        for op in ["..<", "..."] {
            let parts = trimmed.components(separatedBy: op)
            if parts.count == 2,
               let lower = Int(parts[0].trimmingCharacters(in: .whitespaces)),
               let upper = Int(parts[1].trimmingCharacters(in: .whitespaces)),
               (100...599).contains(lower), (100...599).contains(upper) {
                return "\(lower)\(op)\(upper)"
            }
        }

        // Try wildcard: strip trailing wildcard characters, then expand based on digit count
        let digits = trimmed.prefix(while: { $0.isNumber })
        let suffix = trimmed.dropFirst(digits.count)
        let isWildcard = !suffix.isEmpty && suffix.allSatisfy({ "xX*".contains($0) })
        if isWildcard || (digits.count < 3 && suffix.isEmpty),
           let first = digits.first, ("1"..."5").contains(first),
           let base = Int(digits) {
            let multiplier = digits.count == 1 ? 100 : 10
            let lower = base * multiplier
            let upper = (base + 1) * multiplier
            switch (lower, upper) {
            case (100, 200): return "1XX"
            case (200, 300): return "2XX"
            case (300, 400): return "3XX"
            case (400, 500): return "4XX"
            case (500, 600): return "5XX"
            default: return "\(lower)..<\(upper)"
            }
        }

        // Try exact integer
        if let value = Int(trimmed), (100...599).contains(value) {
            return "\(value)"
        }

        return nil
    }
}

#endif
