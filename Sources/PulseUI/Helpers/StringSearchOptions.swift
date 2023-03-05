// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

struct StringSearchOptions: Equatable, Hashable, Codable {
    var kind: Kind = .text
    var caseSensitivity: CaseSensitivity = .ignoringCase
    var rule: MatchingRule = .contains

    static let `default` = StringSearchOptions()

    enum Kind: String, Hashable, Codable, CaseIterable {
        case text = "Text"
        case wildcard = "Wildcard"
        case regex = "Regular Expression"
    }

    enum CaseSensitivity: String, Hashable, Codable, CaseIterable {
        case ignoringCase = "Ignoring Case"
        case matchingCase = "Matching Case"
    }

    enum MatchingRule: String, Equatable, Hashable, Codable, CaseIterable {
        case begins = "Begins With"
        case contains = "Contains"
        case ends = "Ends With"
    }

    var title: String {
        switch kind {
        case .text: return rule.rawValue
        case .wildcard: return "Contains"
        case .regex: return "Regex"
        }
    }

    func allEligibleMatchingRules() -> [MatchingRule]? {
        switch kind {
        case .text, .wildcard: return MatchingRule.allCases
        case .regex: return nil
        }
    }
}

extension String.CompareOptions {
    init(_ options: StringSearchOptions) {
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
            case .begins:
                insert(.anchored)
            case .ends:
                insert(.anchored)
                insert(.backwards)
            case .contains:
                break
            }
        }
    }
}

extension String {
    /// Returns first range of substring.
    func firstRange(of substring: String, options: String.CompareOptions = []) -> Range<String.Index>? {
        range(of: substring, options: options, range: startIndex..<endIndex, locale: nil)
    }
}

extension String {
    func ranges(of target: String, options: StringSearchOptions) -> [Range<String.Index>] {
        var startIndex = target.startIndex
        var ranges = [Range<String.Index>]()
        let target = options.kind == .wildcard ? makeRegexForWildcard(target, rule: options.rule) : target
        let options = String.CompareOptions(options)
        while startIndex < endIndex,
              let range = range(of: target, options: options, range: startIndex..<endIndex, locale: nil) {
            ranges.append(range)
            startIndex = range.upperBound
        }
        return ranges
    }
}

extension NSString {
    func ranges(of substring: String, options: StringSearchOptions) -> [NSRange] {
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
    }
}
