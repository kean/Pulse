// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation
import Pulse

// Search:
//
// - Search with confidence for filter names (and consume it) plus any remaining: symbols
// - If no matched (with high confidence?), search for values

// The patterns are set up with "guesses" around. So if the user enters incorrect
// range, it'll still try to "guess".
extension Parsers {

    // MARK: Logs

    static func makeLogsFilters(context: ConsoleSearchSuggestionsContext) -> [Parser<[(ConsoleSearchFilter, Confidence)]>] {
        return [
            filterLevels,
            makeFilterLabels(labels: context.index.labels),
            makeFilterFiles(files: context.index.files)
        ]
    }

    static func makeFilterLabels(labels: Set<String>) -> Parser<[(ConsoleSearchFilter, Confidence)]> {
        (optional(filterName("label")) <*> listOf(word)).map { confidence, values in
            let filters = String.fuzzyMatch(values: values, from: labels)
                .map { (ConsoleSearchFilter.label(.init(values: [$0.0])), $0.1) }
            let confidence: Confidence = confidence == nil ? 0.0 : 0.7 // below autocompleted
            return filters + [(ConsoleSearchFilter.label(.init(values: values)), confidence)]
        }
    }

    static let filterLevels: Parser<[(ConsoleSearchFilter, Confidence)]> = {
        let map = Dictionary(uniqueKeysWithValues: LoggerStore.Level.allCases.map { ($0.name, $0) })
        let levels = Set(LoggerStore.Level.allCases.map(\.name))
        return (optional(filterName("level")) <*> listOf(word)).map { confidence, values in
            let filters = String.fuzzyMatch(values: values, from: levels)
                .map { (ConsoleSearchFilter.level(.init(values: [map[$0.0]!])), $0.1) }
            let confidence: Confidence = confidence == nil ? 0.0 : 0.7 // below autocompleted
            return filters + [(ConsoleSearchFilter.level(.init(values: values.compactMap { map[$0] })), confidence)]
        }
    }()

    static func makeFilterFiles(files: Set<String>) -> Parser<[(ConsoleSearchFilter, Confidence)]> {
        (optional(filterName("file")) <*> listOf(word)).map { confidence, values in
            let filters = String.fuzzyMatch(values: values, from: files)
                .map { (ConsoleSearchFilter.file(.init(values: [$0.0])), $0.1) }
            let confidence: Confidence = confidence == nil ? 0.0 : 0.7 // below autocompleted
            return filters + [(ConsoleSearchFilter.file(.init(values: values)), confidence)]
        }
    }

    private static let word = char(from: CharacterSet.alphanumerics.union(.punctuationCharacters))
        .oneOrMore.map { String($0 )}

    // MARK: Network

    static func makeNetworkFilters(context: ConsoleSearchSuggestionsContext) -> [Parser<[(ConsoleSearchFilter, Confidence)]>] {
        return [
            filterStatusCode,
            filterMethod,
            makeFilterHost(hosts: context.index.hosts),
            makeFilterPath(paths: context.index.paths)
        ]
    }

    static let filterStatusCode = oneOf(
            filterName("status code") <*> listOf(statusCode),
            // If we find a value in 100...500 range, assign it 0.7 confidence and suggest it
            listOf(statusCode).filter { !$0.isEmpty }.map { (0.7, $0) }
    ).map { confidence, values in
        [(ConsoleSearchFilter.statusCode(.init(values: values)), confidence)]
    }

    static func makeFilterHost(hosts: Set<String>) -> Parser<[(ConsoleSearchFilter, Confidence)]> {
        (optional(filterName("host")) <*> listOf(host)).map { confidence, values in
            let filters = String.fuzzyMatch(values: values, from: hosts)
                .map { (ConsoleSearchFilter.host(.init(values: [$0.0])), $0.1) }
            let confidence: Confidence = confidence == nil ? 0.0 : 0.7 // below autocompleted
            return filters + [(ConsoleSearchFilter.host(.init(values: values)), confidence)]
        }
    }

    static let filterMethod = oneOf(
        filterName("method") <*> listOf(httpMethod),
        listOf(httpMethod).filter { !$0.isEmpty }.map { (0.7, $0) }
    ).map { confidence, values in
        [(ConsoleSearchFilter.method(.init(values: values)), confidence)]
    }

    static func makeFilterPath(paths: Set<String>) -> Parser<[(ConsoleSearchFilter, Confidence)]> {
        oneOf(
            filterName("path") <*> listOf(path),
            (char(from: "/") *> optional(path)).map { (0.7, ["/" + ($0 ?? "")]) }
        ).map { confidence, values in
            let filters = String.fuzzyMatch(values: values, from: paths)
                .map { (ConsoleSearchFilter.path(.init(values: [$0.0])), $0.1) }
            return filters + [(ConsoleSearchFilter.path(.init(values: values)), confidence)]
        }
    }

    static let host = char(from: .urlHostAllowed.subtracting(.init(charactersIn: ",")))
        .oneOrMore.map { String($0) }

    static let path = char(from: .urlPathAllowed.subtracting(.init(charactersIn: ",")))
        .oneOrMore.map { String($0) }

    static let httpMethod = oneOf(HTTPMethod.allCases.map { method in
        fuzzy(method.rawValue, confidence: 0.8).map { _ in method }
    })

    /// Consumes a filter with the given name if it has high enough confidence.
    static func filterName(_ name: String) -> Parser<Confidence> {
        let words = name.split(separator: " ").map { String($0) }
        assert(!words.isEmpty)

        // Try to match as many words as we can in any order
        let anyWords: Parser<Confidence> = oneOf(words.map { fuzzy($0) <* whitespaces }).oneOrMore.map {
            let confidences = Array($0.sorted())
            guard words.count > 1 else {
                return confidences[0]
            }
            guard confidences.count > 1 else {
                return Confidence(confidences[0].rawValue * 0.8)
            }
            let first = confidences[0].rawValue * 0.75 // This is the main contributor
            let remaining = confidences.dropFirst()
                .map { $0.rawValue }
                .reduce(0, +) * (0.25 / Float(confidences.count - 1))
            return Confidence(first + remaining)
        }
        return anyWords <* optional(":") <* whitespaces
    }

    static let statusCode: Parser<ConsoleSearchRange<Int>> = oneOf(
        rangeOfInts(in: 100...599),
        int(in: 100...599).map { ConsoleSearchRange($0) },
        statusCodeWilcard // It'll also auto-complete "2" as "2xx" if every other pattern fails
    )

    static let statusCodeWilcard: Parser<ConsoleSearchRange<Int>> = oneOf(
        (char(from: "12345") <*> char(from: "012345") <* optional(char(from: "xX*")) <* end).map {
            let lowerBound = Int(String($0) + String($1))! * 10
            return ConsoleSearchRange(.open, lowerBound: lowerBound, upperBound: lowerBound + 10)
        },
        (char(from: "12345") <* optional(char(from: "xX*")) <* optional(char(from: "xX*")) <* end).map {
            let lowerBound = Int(String($0))! * 100
            return ConsoleSearchRange(.open, lowerBound: lowerBound, upperBound: lowerBound + 100)
        }
    )

    static func rangeOfInts(in range: ClosedRange<Int>) -> Parser<ConsoleSearchRange<Int>> {
        rangeOfInts.filter {
            range.contains($0.lowerBound) && range.contains($0.upperBound)
        }
    }

    static func int(in range: ClosedRange<Int>) -> Parser<Int> {
        int.filter { range.contains($0) }
    }

    static let rangeOfInts: Parser<ConsoleSearchRange<Int>> = zip(int, rangeModifier, int)
        .map { lowerBound, modifier, upperBound in
            switch modifier {
            case .open: return .init(.open, lowerBound: lowerBound, upperBound: upperBound)
            case .closed: return .init(.closed, lowerBound: lowerBound, upperBound: upperBound)
            }
        }

    /// Parses a comma-separated list of values. The given parser receives a
    /// trimmed string with not separators and doesn't need to consume input.
    /// The `listOf` consumes values even if it fails to parse some of them.
    static func listOf<T>(_ parser: Parser<T>) -> Parser<[T]> {
        let value: Parser<T?> = string(excluding: ", ").map { try? parser.parse($0) }
        return (value <* optional(",") <* whitespaces).zeroOrMore.map { $0.compactMap { $0} }
    }

    static let rangeModifier: Parser<ConsoleSearchRangeModfier> = whitespaces *> oneOf(
        oneOf("-", "–", "<=", "...").map { _ in .closed }, // important: order
        oneOf("<", ".<", "..<").map { _ in .open },
        string("..").map { _ in .closed }
    ) <* whitespaces
}

enum HTTPMethod: String, Hashable, Codable, CaseIterable, CustomStringConvertible {
    case get = "GET"
    case head = "HEAD"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case connect = "CONNECT"
    case options = "OPTIONS"
    case trace = "TRACE"

    var description: String { rawValue }
}

#endif
