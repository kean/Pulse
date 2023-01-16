// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

enum ConsoleSearchFilter: Hashable {
    case statusCode(StatusCode)
    case host(Host)

    struct StatusCode: Hashable {
        var isNot: Bool
        var values: [ConsoleSearchRange<Int>]
    }

    struct Host: Hashable {
        var isNot: Bool
        var values: [String]
    }
}

extension Parsers {
    static let filterStatusCode = (filterName("status code") *> not <*> listOf(rangeOfInts))
        .map(ConsoleSearchFilter.StatusCode.init)

    static let filterHost = (filterName("host") *> not <*> listOf(word))
        .map(ConsoleSearchFilter.Host.init)

    static func filterName(_ name: String) -> Parser<Void> {
        let words = name.split(separator: " ").map { String($0) }
        assert(!words.isEmpty)
        let anyWords = oneOf(words.map(fuzzy)).oneOrMore.map { _ in () }
        return anyWords <* optional(":") <* whitespaces
    }

    static let rangeOfInts: Parser<ConsoleSearchRange<Int>> = oneOf(
        zip(int, rangeModifier, int).map { lowerBound, modifier, upperBound in
            switch modifier {
            case .open: return .init(.open, lowerBound: lowerBound, upperBound: upperBound)
            case .closed: return .init(.closed, lowerBound: lowerBound, upperBound: upperBound)
            }
        },
        int.map(ConsoleSearchRange.init)
    )

    static let not: Parser<Bool> = optional(oneOf(prefixIgnoringCase("not"), "!") *> whitespaces)
        .map { $0 != nil }

    /// A comma or space separated list.
    static func listOf<T>(_ parser: Parser<T>) -> Parser<[T]> {
        (parser <* optional(",") <* whitespaces).zeroOrMore
    }

    static let rangeModifier: Parser<ConsoleSearchRangeModfier> = whitespaces *> oneOf(
        oneOf("-", "–", "<=", "...").map { _ in .closed }, // important: order
        oneOf("<", ".<", "..<").map { _ in .open },
        string("..").map { _ in .closed }
    ) <* whitespaces

}

enum ConsoleSearchRangeModfier {
    case open, closed
}

struct ConsoleSearchRange<T: Hashable & Comparable>: Hashable {
    var modifier: ConsoleSearchRangeModfier
    var lowerBound: T
    var upperBound: T

    init(_ modifier: ConsoleSearchRangeModfier, lowerBound: T, upperBound: T) {
        self.modifier = modifier
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    init(_ value: T) {
        self.modifier = .closed
        self.lowerBound = value
        self.upperBound = value
    }

    var title: String {
        guard upperBound > lowerBound else { return "\(lowerBound)" }
        switch modifier {
        case .open: return "\(lowerBound)..<\(upperBound)"
        case .closed: return "\(lowerBound)...\(upperBound)"
        }
    }
}

extension ConsoleSearchRange where T == Int {
    var range: ClosedRange<Int>? {
        guard upperBound > lowerBound else { return nil }
        switch modifier {
        case .open: return ClosedRange(lowerBound..<upperBound)
        case .closed: return lowerBound...upperBound
        }
    }
}
