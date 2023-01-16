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
    static let filterStatusCode = (filterName("status code") *> not <*> listOf(searchValueInt))
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

    static let searchValueInt: Parser<ConsoleSearchRange<Int>> = oneOf(
        zip(int, rangeModifier, int).map { lowerBound, modifier, upperBound in
            switch modifier {
            case .open: return .openRange(lowerBound: lowerBound, upperBound: upperBound)
            case .closed: return .closedRange(lowerBound: lowerBound, upperBound: upperBound)
            }
        },
        int.map(ConsoleSearchRange.exact)
    )

    static let not: Parser<Bool> = optional(oneOf(prefixIgnoringCase("not"), "!") *> whitespaces)
        .map { $0 != nil }

    /// A comma or space separated list.
    static func listOf<T>(_ parser: Parser<T>) -> Parser<[T]> {
        (parser <* optional(",") <* whitespaces).zeroOrMore
    }

    static let rangeModifier: Parser<RangeModfier> = whitespaces *> oneOf(
        oneOf("-", "–", "<=", "...").map { _ in .closed }, // important: order
        oneOf("<", ".<", "..<").map { _ in .open },
        string("..").map { _ in .closed }
    ) <* whitespaces

    enum RangeModfier {
        case open, closed
    }
}

#warning("TODO: do we need this? can we use ClosedRange instead?")
enum ConsoleSearchRange<T: Hashable>: Hashable {
    case exact(_ value: T)
    case openRange(lowerBound: T, upperBound: T)
    case closedRange(lowerBound: T, upperBound: T)

    var title: String {
        switch self {
        case .exact(let value):
            return "\(value)"
        case .openRange(let lowerBound, let upperBound):
            return "\(lowerBound)..<\(upperBound)"
        case .closedRange(let lowerBound, let upperBound):
            return "\(lowerBound)...\(upperBound)"
        }
    }
}

extension ConsoleSearchRange where T == Int {
    var range: ClosedRange<Int>? {
        switch self {
        case .exact(let value):
            return value...value
        case .openRange(let lowerBound, let upperBound):
            guard upperBound > lowerBound else { return nil }
            return lowerBound...(upperBound-1)
        case .closedRange(let lowerBound, let upperBound):
            guard upperBound > lowerBound else { return nil }
            return lowerBound...upperBound
        }
    }
}
