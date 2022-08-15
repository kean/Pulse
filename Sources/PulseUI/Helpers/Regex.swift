// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

final class Regex {
    static var isDebugModeEnabled = false

    var numberOfCaptureGroups: Int {
        return regex.numberOfCaptureGroups
    }

    private let regex: NSRegularExpression

    struct Options: OptionSet {
        let rawValue: Int

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        static let caseInsensitive = Options(rawValue: 1 << 0)
        static let multiline = Options(rawValue: 1 << 1)
        static let dotMatchesLineSeparators = Options(rawValue: 1 << 2)
    }

    init(_ pattern: String, _ options: Options = []) throws {
        var ops = NSRegularExpression.Options()
        if options.contains(.caseInsensitive) { ops.insert(.caseInsensitive) }
        if options.contains(.multiline) { ops.insert(.anchorsMatchLines) }
        if options.contains(.dotMatchesLineSeparators) { ops.insert(.dotMatchesLineSeparators)}

        self.regex = try NSRegularExpression(pattern: pattern, options: ops)
    }

    func isMatch(_ s: String) -> Bool {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return regex.firstMatch(in: s, options: [], range: range) != nil
    }

    func matches(in s: String) -> [Match] {
        let range = NSRange(s.startIndex..<s.endIndex, in: s)
        return matches(in: s, range: range)
    }

    func matches(in s: String, range: NSRange) -> [Match] {
        let matches = regex.matches(in: s, options: [], range: range)
        return matches.map { match in
            let ranges = (0..<match.numberOfRanges)
                .map { match.range(at: $0) }
                .filter { $0.location != NSNotFound }
            return Match(fullMatch: s[Range(match.range, in: s)!],
                         groups: ranges.dropFirst().map { s[Range($0, in: s)!] }
            )
        }
    }
}

extension Regex {
    struct Match {
        let fullMatch: Substring
        let groups: [Substring]
    }
}

extension Regex {
    struct Error: Swift.Error, LocalizedError {
        let message: String
        let index: Int
        var pattern: String = ""
    }
}
