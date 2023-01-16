// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

extension Parsers {
    static let filterStatusCode = (filterName("status code") *> listOf(rangeOfInts))
        .map(ConsoleSearchFilterStatusCode.init).map(ConsoleSearchFilter.statusCode)

    static let filterHost = (filterName("host") *> listOf(host))
        .map(ConsoleSearchFilterHost.init).map(ConsoleSearchFilter.host)

    static let host = char(from: .urlHostAllowed.subtracting(.init(charactersIn: ","))).oneOrMore.map { String($0) }

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
