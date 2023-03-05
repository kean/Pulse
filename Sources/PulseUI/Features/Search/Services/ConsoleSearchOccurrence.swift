// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, *)
final class ConsoleSearchOccurrence: Identifiable, Equatable, Hashable {
    let id = ConsoleSearchOccurrenceId()
    let scope: ConsoleSearchScope
    let match: ConsoleSearchMatch
    var line: Int { match.lineNumber }
    var range: NSRange { NSRange(match.range, in: match.line) }
    lazy var preview = ConsoleSearchOccurrence.makePreview(for: match, attributes: previewAttibutes)
    let searchContext: RichTextViewModel.SearchContext

    init(scope: ConsoleSearchScope,
         match: ConsoleSearchMatch,
         searchContext: RichTextViewModel.SearchContext) {
        self.scope = scope
        self.match = match
        self.searchContext = searchContext
    }

    static func == (lhs: ConsoleSearchOccurrence, rhs: ConsoleSearchOccurrence) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

private let previewAttibutes = TextHelper().attributes(role: .body2, style: .monospaced)

@available(iOS 15, *)
extension ConsoleSearchOccurrence {
    static func makePreview(for match: ConsoleSearchMatch, attributes customAttributes: [NSAttributedString.Key: Any] = [:]) -> AttributedString {

        let prefixStartIndex = match.line.index(match.range.lowerBound, offsetBy: -50, limitedBy: match.line.startIndex) ?? match.line.startIndex
        let prefixRange = prefixStartIndex..<match.range.lowerBound

        let suffixUpperBound = match.line.index(match.range.upperBound, offsetBy: 200, limitedBy: match.line.endIndex) ?? match.line.endIndex
        let suffixRange = match.range.upperBound..<suffixUpperBound

        func shouldTrim(_ character: Character) -> Bool {
            character.isNewline || character.isWhitespace || character == ","
        }

        var prefix = match.line[prefixRange]
        let isEllipsisNeeded = prefix.startIndex != match.line.startIndex
        prefix.trimPrefix(while: shouldTrim)

        var suffix = match.line[suffixRange]
        suffix.trimSuffix(while: shouldTrim)

        if isEllipsisNeeded {
            prefix.insert("…", at: prefix.startIndex)
        }

        let attributes = AttributeContainer(customAttributes)
        var middle = AttributedString(match.line[match.range], attributes: attributes)
        middle.foregroundColor = .orange
        return AttributedString(prefix, attributes: attributes) + middle + AttributedString(suffix, attributes: attributes)
    }
}

private extension Substring {
    mutating func trimPrefix(while closure: (Character) -> Bool) {
        while let character = first, closure(character) {
            removeFirst()
        }
    }

    mutating func trimSuffix(while closure: (Character) -> Bool) {
        while let character = last, closure(character) {
            removeLast()
        }
    }
}

struct ConsoleSearchOccurrenceId: Hashable {
    let id = UUID()
}

#endif
