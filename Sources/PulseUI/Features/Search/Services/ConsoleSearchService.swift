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
    func search(in task: NetworkTaskEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurence] {
        var occurences: [ConsoleSearchOccurence] = []
        for kind in ConsoleSearchOccurence.Kind.allCases {
            switch kind {
            case .url:
                if var components = URLComponents(string: task.url ?? "") {
                    components.queryItems = nil
                    if let url = components.url?.absoluteString {
                        occurences += search(url as NSString, parameters, kind)
                    }
                }
            case .queryItems:
                if let components = URLComponents(string: task.url ?? ""),
                   let query = components.query, !query.isEmpty {
                    occurences += search(query as NSString, parameters, kind)
                }
            case .originalRequestHeaders:
                if let headers = task.originalRequest?.httpHeaders {
                    occurences += search(headers as NSString, parameters, kind)
                }
            case .currentRequestHeaders:
                if let headers = task.currentRequest?.httpHeaders {
                    occurences += search(headers as NSString, parameters, kind)
                }
            case .requestBody:
                if let data = task.requestBody?.data {
                    occurences += search(data, parameters, kind)
                }
            case .responseHeaders:
                if let headers = task.response?.httpHeaders {
                    occurences += search(headers as NSString, parameters, kind)
                }
            case .responseBody:
                if let data = task.responseBody?.data {
                    occurences += search(data, parameters, kind)
                }
            }
        }
        return occurences
    }

    private func search(_ data: Data, _ parameters: ConsoleSearchParameters, _ kind: ConsoleSearchOccurence.Kind) -> [ConsoleSearchOccurence] {
        guard let content = NSString(data: data, encoding: NSUTF8StringEncoding) else {
            return []
        }
        return search(content, parameters, kind)
    }

    private func search(_ content: NSString, _ parameters: ConsoleSearchParameters, _ kind: ConsoleSearchOccurence.Kind) -> [ConsoleSearchOccurence] {
        var allMatches: [(line: NSString, lineNumber: Int, range: NSRange)] = []
        var lineCount = 0
        content.enumerateLines { line, stop in
            lineCount += 1
            let line = line as NSString
            let matches = line.ranges(of: parameters.searchTerm, options: .init(parameters.options))
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
            if let range = preview.range(of: parameters.searchTerm, options: .init(parameters.options)) {
                preview[range].foregroundColor = .orange
            }

            #warning("replace searchContext with ConsoleSearchParameters")
            let occurence = ConsoleSearchOccurence(
                kind: kind,
                line: lineNumber,
                range: range,
                text: preview,
                searchContext: .init(searchTerm: parameters.searchTerm, options: parameters.options, matchIndex: matchIndex)
            )
            occurences.append(occurence)

            matchIndex += 1
        }

        return occurences
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchOccurence {
    enum Kind: CaseIterable {
        case url
        case queryItems
        case originalRequestHeaders
        case currentRequestHeaders
        case requestBody
        case responseHeaders
        case responseBody

        var title: String {
            switch self {
            case .url: return "URL"
            case .queryItems: return "Query Items"
            case .originalRequestHeaders: return "Original Request Headers"
            case .currentRequestHeaders: return "Current Request Headers"
            case .requestBody: return "Request Body"
            case .responseHeaders: return "Response Headers"
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

final class ConsoleSearchParameters {
    let searchTerm: String
    let tokens: [ConsoleSearchToken]
    let options: StringSearchOptions

    init(searchTerm: String, tokens: [ConsoleSearchToken], options: StringSearchOptions) {
        self.searchTerm = searchTerm
        self.tokens = tokens
        self.options = options
    }
}

#warning("when you are typing search, add -headers contains, -requety body: contains, etc")
#warning("how to view all suggestions?")
#warning("how to surface these to the user?")
#warning("add support for basic wildcards")
#warning("add a way to enable regex")

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

    case status(range: ClosedRange<Int>, isNot: Bool)
    @available(iOS 15, tvOS 15, *)
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
