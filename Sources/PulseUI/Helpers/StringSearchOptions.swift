// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation

package struct StringSearchOptions: Equatable, Hashable, Codable {
    package var kind: Kind
    package var caseSensitivity: CaseSensitivity
    package var rule: MatchingRule

    package static let `default` = StringSearchOptions()

    package init(kind: Kind = .text, caseSensitivity: CaseSensitivity = .ignoringCase, rule: MatchingRule = .contains) {
        self.kind = kind
        self.caseSensitivity = caseSensitivity
        self.rule = rule
    }

    package enum Kind: String, Hashable, Codable, CaseIterable {
        case text = "Text"
        case multipleWords = "Multiple Words"
        case wildcard = "Wildcard"
        case regex = "Regular Expression"
    }

    package enum CaseSensitivity: String, Hashable, Codable, CaseIterable {
        case ignoringCase = "Ignoring Case"
        case matchingCase = "Matching Case"
    }

    package enum MatchingRule: String, Equatable, Hashable, Codable, CaseIterable {
        case contains = "Containing"
        case equal = "Matching"
        case begins = "Starting With"
        case ends = "Ending With"
        case word = "Matching Word"
    }

    package var title: String {
        switch kind {
        case .text: return rule.rawValue
        case .multipleWords: return "Multiple Words"
        case .wildcard: return "Contains"
        case .regex: return "Regex"
        }
    }

    /// Converts this options to an equivalent regex-based options, preserving case sensitivity.
    var asRegex: StringSearchOptions {
        StringSearchOptions(kind: .regex, caseSensitivity: caseSensitivity)
    }

    package func allEligibleMatchingRules() -> [MatchingRule]? {
        switch kind {
        case .text: return MatchingRule.allCases
        case .wildcard: return [.begins, .contains, .ends, .equal]
        case .multipleWords, .regex: return nil
        }
    }

    /// Returns `true` when `string` satisfies this search options against `value`.
    package func matches(_ string: String, value: String) -> Bool {
        switch kind {
        case .text where rule == .word:
            return asRegex.matches(string, value: wordBoundaryPattern(for: value))
        case .text where rule == .equal:
            switch caseSensitivity {
            case .ignoringCase: return string.caseInsensitiveCompare(value) == .orderedSame
            case .matchingCase: return string == value
            }
        case .multipleWords:
            let words = splitWords(value)
            guard !words.isEmpty else { return false }
            let compareOptions = String.CompareOptions(caseSensitivity == .ignoringCase ? [.caseInsensitive] : [])
            return words.allSatisfy { string.firstRange(of: $0, options: compareOptions) != nil }
        case .text, .wildcard, .regex:
            let pattern = kind == .wildcard ? makeRegexForWildcard(value, rule: rule) : value
            return string.firstRange(of: pattern, options: String.CompareOptions(self)) != nil
        }
    }

    /// Builds an `NSPredicate` that applies this search options to the given Core Data `key`.
    package func predicate(key: String, value: String) -> NSPredicate {
        let cs = caseSensitivity == .ignoringCase ? "[c]" : ""
        if kind == .text && rule == .word {
            let pattern = "(^|.*\\b)" + NSRegularExpression.escapedPattern(for: value) + "(\\b.*|$)"
            return NSPredicate(format: "\(key) MATCHES\(cs) %@", pattern)
        }
        switch kind {
        case .text:
            switch rule {
            case .contains: return NSPredicate(format: "\(key) CONTAINS\(cs) %@", value)
            case .begins: return NSPredicate(format: "\(key) BEGINSWITH\(cs) %@", value)
            case .ends: return NSPredicate(format: "\(key) ENDSWITH\(cs) %@", value)
            case .equal: return NSPredicate(format: "\(key) LIKE\(cs) %@", value)
            case .word: fatalError() // Handled above
            }
        case .multipleWords:
            let words = splitWords(value)
            let predicates = words.map { NSPredicate(format: "\(key) CONTAINS\(cs) %@", $0) }
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        case .wildcard:
            let pattern = makeRegexForWildcard(value, rule: rule)
            return NSPredicate(format: "\(key) MATCHES %@", pattern)
        case .regex:
            return NSPredicate(format: "\(key) MATCHES %@", value)
        }
    }
}

extension String.CompareOptions {
    package init(_ options: StringSearchOptions) {
        self.init()
        if options.kind == .regex || options.kind == .wildcard {
            insert(.regularExpression)
        }
        switch options.caseSensitivity {
        case .ignoringCase:
            insert(.caseInsensitive)
        case .matchingCase:
            break
        }
        if options.kind == .text {
            switch options.rule {
            case .begins, .equal:
                insert(.anchored)
            case .ends:
                insert(.anchored)
                insert(.backwards)
            case .contains, .word:
                break
            }
        }
    }
}

extension String {
    /// Returns first range of substring.
    package func firstRange(of substring: String, options: String.CompareOptions = []) -> Range<String.Index>? {
        range(of: substring, options: options, range: startIndex..<endIndex, locale: nil)
    }
}

extension String {
    package func ranges(of target: String, options: StringSearchOptions, limit: Int = Int.max) -> [Range<String.Index>] {
        if options.kind == .multipleWords {
            let words = splitWords(target)
            let compareOptions = String.CompareOptions(options.caseSensitivity == .ignoringCase ? [.caseInsensitive] : [])
            var allRanges = [Range<String.Index>]()
            for word in words {
                var startIndex = self.startIndex
                while allRanges.count < limit,
                      startIndex < endIndex,
                      let range = range(of: word, options: compareOptions, range: startIndex..<endIndex, locale: nil) {
                    allRanges.append(range)
                    startIndex = range.upperBound
                }
            }
            return allRanges.sorted { $0.lowerBound < $1.lowerBound }
        }
        if options.kind == .text && options.rule == .word {
            return ranges(of: wordBoundaryPattern(for: target), options: options.asRegex, limit: limit)
        }
        var startIndex = target.startIndex
        var ranges = [Range<String.Index>]()
        let target = options.kind == .wildcard ? makeRegexForWildcard(target, rule: options.rule) : target
        let options = String.CompareOptions(options)
        while ranges.count < limit,
                startIndex < endIndex,
              let range = range(of: target, options: options, range: startIndex..<endIndex, locale: nil) {
            ranges.append(range)
            startIndex = range.upperBound
        }
        return ranges
    }
}

extension NSString {
    /// - note: Intentionally duplicates `String.ranges(of:options:)` to avoid
    ///   bridging overhead and work directly with integer offsets / `NSRange`.
    package func ranges(of substring: String, options: StringSearchOptions) -> [NSRange] {
        if options.kind == .multipleWords {
            let words = splitWords(substring)
            let compareOptions = NSString.CompareOptions(options.caseSensitivity == .ignoringCase ? [.caseInsensitive] : [])
            var allRanges = [NSRange]()
            for word in words {
                var index = 0
                while index < length {
                    let range = range(of: word, options: compareOptions, range: NSRange(location: index, length: length - index), locale: nil)
                    if range.location == NSNotFound { break }
                    allRanges.append(range)
                    index = range.upperBound
                }
            }
            return allRanges.sorted { $0.location < $1.location }
        }
        if options.kind == .text && options.rule == .word {
            return ranges(of: wordBoundaryPattern(for: substring), options: options.asRegex)
        }
        var index = 0
        var ranges = [NSRange]()
        let substring = options.kind == .wildcard ? makeRegexForWildcard(substring, rule: options.rule) : substring
        let options = NSString.CompareOptions(options)
        while index < length {
            let range = range(of: substring, options: options, range: NSRange(location: index, length: length - index), locale: nil)
            if range.location == NSNotFound {
                return ranges
            }
            ranges.append(range)
            index = range.upperBound
        }
        return ranges
    }
}

private func wordBoundaryPattern(for value: String) -> String {
    "\\b" + NSRegularExpression.escapedPattern(for: value) + "\\b"
}

private func splitWords(_ value: String) -> [String] {
    value.split(whereSeparator: \.isWhitespace).map(String.init)
}

private func makeRegexForWildcard(_ pattern: String, rule: StringSearchOptions.MatchingRule) -> String {
    let pattern = NSRegularExpression.escapedPattern(for: pattern)
        .replacingOccurrences(of: "\\?", with: ".")
        .replacingOccurrences(of: "\\*", with: "[^\\s]*")
    switch rule {
    case .contains:
        return pattern
    case .begins:
        return "^" + pattern
    case .ends:
        return pattern + "$"
    case .equal:
        return "^" + pattern + "$"
    case .word:
        fatalError() // Handled by converting to regex
    }
}
