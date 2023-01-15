// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchService {

    func filter(task: NetworkTaskEntity, tokens: [ConsoleSearchToken]) -> Bool {
        for token in tokens {
            if !filter(task: task, token: token) {
                return false
            }
        }
        return true
    }

    func filter(task: NetworkTaskEntity, token: ConsoleSearchToken) -> Bool {
        switch token {
        case .status(let range, let isNot):
            let contains = range.contains(Int(task.statusCode))
            return isNot ? !contains : contains
        }
    }

    // TODO: cache response bodies in memory
    func search(_ kind: ConsoleSearchOccurence.Kind, in task: NetworkTaskEntity, searchText: String, options: StringSearchOptions) -> [ConsoleSearchOccurence] {
        guard let data = task.responseBody?.data,
              let content = NSString(data: data, encoding: NSUTF8StringEncoding)
        else { return [] }

        var allMatches: [(line: NSString, lineNumber: Int, range: NSRange)] = []
        var lineCount = 0
        content.enumerateLines { line, stop in
            lineCount += 1
            let line = line as NSString
            let matches = line.ranges(of: searchText, options: .init(options))
            for range in matches {
                allMatches.append((line, lineCount, range))
            }
        }


        var occurences: [ConsoleSearchOccurence] = []
        var matchIndex = 0
        for (line, lineNumber, range) in allMatches {
            let lineRange = lineCount == 1 ? NSRange(location: 0, length: content.length) :  (line.getLineRange(range) ?? range) // Optimization for long lines
            var contextRange = lineRange
            while contextRange.length > 0 {
                guard let character = Character(line.character(at: contextRange.upperBound - 1)),
                      character.isNewline || character.isWhitespace || character == ","
                else { break }
                contextRange.length -= 1
            }

            // TODO: is this OK
            var prefix = ""
            if lineRange.length > 300, range.location - contextRange.location > 16 {
                contextRange.length -= (range.location - contextRange.location - 16)
                contextRange.location = range.location - 16
                prefix = "…"
            }
            contextRange.length = min(contextRange.length, 500)

            // TODO: reuse renderer

            let previewText = (prefix + line.substring(with: contextRange))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var preview = AttributedString(previewText, attributes: AttributeContainer(TextHelper().attributes(role: .body2, style: .monospaced)))
            if let range = preview.range(of: searchText, options: .init(options)) {
                preview[range].foregroundColor = .orange
            }

            let occurence = ConsoleSearchOccurence(
                kind: .responseBody,
                line: lineNumber,
                range: range,
                text: preview,
                searchContext: .init(searchTerm: searchText, options: options, matchIndex: matchIndex)
            )
            occurences.append(occurence)

            matchIndex += 1
        }

        return occurences
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchOccurence {
    enum Kind {
        case responseBody

        var title: String {
            switch self {
            case .responseBody: return "Response Body"
            }
        }
    }

    let kind: Kind
    let line: Int
    let range: NSRange
    let text: AttributedString
    let searchContext: RichTextViewModel.SearchContext
}

// TODO: (when entering text)
// Response Body contains:
// Request Body contains:
// show more

@available(iOS 15, tvOS 15, *)
enum ConsoleSearchToken: Identifiable, Hashable {
    var id: ConsoleSearchToken { self }

    case status(range: ClosedRange<Int>, isNot: Bool)

    var title: AttributedString {
        switch self {
        case .status(let range, let isNot):
            let value: String
            if range.count == 1 {
                value = "\(isNot ? "NOT " : "")\(range.lowerBound)"
            } else {
                value = "\(isNot ? "NOT IN " : "")\(range.lowerBound)...\(range.upperBound)"
            }
            return AttributedString("Status Code: ") { $0.foregroundColor = .secondary } + AttributedString(value)
        }
    }
}
