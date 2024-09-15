// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

package final class Regex: @unchecked Sendable {
    private let regex: NSRegularExpression

    package struct Options: OptionSet {
        package let rawValue: Int
        package init(rawValue: Int) { self.rawValue = rawValue }

        package static let caseInsensitive = Options(rawValue: 1 << 0)
        package static let multiline = Options(rawValue: 1 << 1)
        package static let dotMatchesLineSeparators = Options(rawValue: 1 << 2)
    }

    package init(_ pattern: String, _ options: Options = []) throws {
        var ops = NSRegularExpression.Options()
        if options.contains(.caseInsensitive) { ops.insert(.caseInsensitive) }
        if options.contains(.multiline) { ops.insert(.anchorsMatchLines) }
        if options.contains(.dotMatchesLineSeparators) { ops.insert(.dotMatchesLineSeparators)}

        self.regex = try NSRegularExpression(pattern: pattern, options: ops)
    }

    package func isMatch(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.firstMatch(in: s, options: [], range: range) != nil
    }
}
