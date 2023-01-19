// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

struct StringSearchOptions: Equatable, Hashable, Codable {
    var isRegex = false
    var caseSensitivity: CaseSensitivity = .ignoringCase
    var kind: Kind = .contains

    static let `default` = StringSearchOptions()

    enum CaseSensitivity: String, Hashable, Codable, CaseIterable {
        case ignoringCase = "Ignoring Case"
        case matchingCase = "Matching Case"
    }

    enum Kind: String, Equatable, Hashable, Codable, CaseIterable {
        case begins = "Begins With"
        case contains = "Contains"
        case ends = "Ends With"
    }

    var title: String {
        isRegex ? "Regex" : kind.rawValue
    }

    func allKindCases() -> [Kind] {
        if isRegex {
            return [.begins, .contains]
        } else {
            return Kind.allCases
        }
    }
}

extension String.CompareOptions {
    init(_ options: StringSearchOptions) {
        self.init()
        if options.isRegex {
            insert(.regularExpression)
        }
        switch options.caseSensitivity {
        case .ignoringCase:
            insert(.caseInsensitive)
        case .matchingCase:
            break
        }
        switch options.kind {
        case .begins:
            insert(.anchored)
        case .ends:
            if !options.isRegex {
                insert(.anchored)
                insert(.backwards)
            }
        case .contains:
            break
        }
    }
}

extension String {
    /// Returns first range of substring.
    func firstRange(of substring: String, options: String.CompareOptions = []) -> Range<String.Index>? {
        range(of: substring, options: options, range: startIndex..<endIndex, locale: nil)
    }
}

extension NSString {
    func ranges(of substring: String, options: StringSearchOptions) -> [NSRange] {
        var index = 0
        var ranges = [NSRange]()
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
