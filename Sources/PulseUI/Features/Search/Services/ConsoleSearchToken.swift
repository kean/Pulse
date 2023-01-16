// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#warning("when you are typing search, add -headers contains, -requety body: contains, etc")
#warning("how to view all suggestions?")
#warning("how to surface these to the user?")
#warning("add support for basic wildcards")
#warning("add a way to enable regex")

#warning("remove ConsoleSearchToken and have separate filters and scope")

// network:
//
// - "url" <value>
// - "host" = <value> (+add commons hosts)
// - "domain" = <value>
// - "method" <value>
// - "path" <value>
// - "scheme" <value>
// - "duration" ">=" "<=" <value>
// - "\(kind)" "contains" <value>
// - "type" data/download/upload/stream/socket
// - "cookies" empty/non-empty/contains
// - "timeout" >= <=
// - "error"
// - "size" >= <= <value>
// - "error code" <value>
// - "error decoding failed"
// - "content-type" <value>
// - "cached"
// - "redirect"
// - "pins"
//
// message:
//
// - "label" <value>
// - "log level" or "level"
// - "metadata"
// - "file" <value>
enum ConsoleSearchToken: Identifiable, Hashable {
    var id: ConsoleSearchToken { self }

    case filter(ConsoleSearchFilter)

    var systemImage: String {
        switch self {
        case .filter:
            return "line.3.horizontal.decrease.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .filter(let filter):
            switch filter {
            case .statusCode(let statusCode):
                guard statusCode.values.count > 0 else {
                    return "Status Code" // Should never happen
                }
                let title = statusCode.values[0].title
                return statusCode.values.count > 1 ? title + "…" : title
            }
        }
    }
}

enum ConsoleSearchFilter: Hashable {
    case statusCode(StatusCode)

    struct StatusCode: Hashable {
        var isNot: Bool
        var values: [ConsoleSearchRange<Int>]
    }
}

extension Parsers {
    static let filterStatusCode = (filterName("status code") *> not <*> listOf(rangeOfInts))
        .map(ConsoleSearchFilter.StatusCode.init)

    static func filterName(_ name: String) -> Parser<Void> {
        let words = name.split(separator: " ").map { String($0) }
        assert(!words.isEmpty)
        var parser = prefixIgnoringCase(words[0])
        for word in words.dropFirst() {
            parser = parser <* whitespaces <* optional(prefixIgnoringCase(word))
        }
        return whitespaces <* parser <* optional(":") <* whitespaces
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
