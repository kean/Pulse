// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(macOS)
import AppKit
#endif

@available(iOS 16, visionOS 1, *)
package final class ConsoleSearchOccurrence: Identifiable, Equatable, Hashable {
    package let id = ConsoleSearchOccurrenceId()
    package let scope: ConsoleSearchScope
    package let match: ConsoleSearchMatch
    package var line: Int { match.lineNumber }
    package var range: NSRange { NSRange(match.range, in: match.line) }
    package lazy var preview = ConsoleSearchOccurrence.makePreview(for: match, attributes: previewAttibutes)
    package let searchContext: TextViewSearchContext

    package init(scope: ConsoleSearchScope,
         match: ConsoleSearchMatch,
         searchContext: TextViewSearchContext) {
        self.scope = scope
        self.match = match
        self.searchContext = searchContext
    }

    package static func == (lhs: ConsoleSearchOccurrence, rhs: ConsoleSearchOccurrence) -> Bool {
        lhs.id == rhs.id
    }

    package func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}

private let previewAttibutes = TextHelper().attributes(role: .body2, style: .monospaced)

@available(iOS 16, visionOS 1, *)
extension ConsoleSearchOccurrence {
    package static func makePreview(for match: ConsoleSearchMatch, attributes customAttributes: [NSAttributedString.Key: Any] = [:]) -> AttributedString {
        let segments = makePreviewSegments(for: match)

        var attributes = AttributeContainer(customAttributes)
#if os(macOS)
        attributes.foregroundColor = .secondary
        attributes.font = .callout
#endif

        var middle = AttributedString(segments[1], attributes: attributes)
#if os(macOS)
        middle.foregroundColor = .primary
        middle.font = Font.callout.weight(.semibold)
#else
        middle.foregroundColor = .orange
#endif
        return AttributedString(segments[0], attributes: attributes) + middle + AttributedString(segments[2], attributes: attributes)
    }

    package static func makePreviewSegments(for match: ConsoleSearchMatch) -> [Substring] {
        let prefixOffset: Int
#if os(macOS)
        prefixOffset = -20
#else
        prefixOffset = -50
#endif
        let prefixStartIndex = match.line.index(match.range.lowerBound, offsetBy: prefixOffset, limitedBy: match.line.startIndex) ?? match.line.startIndex
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
        return [prefix, match.line[match.range], suffix]
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

package struct ConsoleSearchOccurrenceId: Hashable {
    package let id = UUID()
}

#endif
