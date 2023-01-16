// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#warning("cache response bodies")
#warning("save duplicated results for bodies")
#warning("construct prefix searchtree or proper index (?)")

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchService {
    private let helper = TextHelper()

    func isMatching(_ task: NetworkTaskEntity, filters: [ConsoleSearchFilter]) -> Bool {
        for filter in filters {
            if !isMatching(task, filter: filter) {
                return false
            }
        }
        return true
    }

#warning("TODO: host to support wildcards")

    func isMatching(_ task: NetworkTaskEntity, filter: ConsoleSearchFilter) -> Bool {
        switch filter {
        case .statusCode(let filter):
            let contains = filter.values
                .compactMap { $0.range }
                .contains { $0.contains(Int(task.statusCode)) }
            return filter.isNot ? !contains : contains
        case .host(let filter):
            guard let host = task.url.flatMap(URL.init)?.host else {
                return false
            }
            let contains = filter.values
                .contains { host.contains($0) }
            return filter.isNot ? !contains : contains
        }
    }

    // TODO: cache response bodies in memory
    func search(in task: NetworkTaskEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurence] {
        var occurences: [ConsoleSearchOccurence] = []
        for scope in parameters.scopes {
            switch scope {
            case .url:
                if var components = URLComponents(string: task.url ?? "") {
                    components.queryItems = nil
                    if let url = components.url?.absoluteString {
                        occurences += search(url as NSString, parameters, scope)
                    }
                }
            case .queryItems:
                if let components = URLComponents(string: task.url ?? ""),
                   let query = components.query, !query.isEmpty {
                    occurences += search(query as NSString, parameters, scope)
                }
            case .originalRequestHeaders:
                if let headers = task.originalRequest?.httpHeaders {
                    occurences += search(headers as NSString, parameters, scope)
                }
            case .currentRequestHeaders:
                if let headers = task.currentRequest?.httpHeaders {
                    occurences += search(headers as NSString, parameters, scope)
                }
            case .requestBody:
                if let data = task.requestBody?.data {
                    occurences += search(data, parameters, scope)
                }
            case .responseHeaders:
                if let headers = task.response?.httpHeaders {
                    occurences += search(headers as NSString, parameters, scope)
                }
            case .responseBody:
                if let data = task.responseBody?.data {
                    occurences += search(data, parameters, scope)
                }
            }
        }
        return occurences
    }

    private func search(_ data: Data, _ parameters: ConsoleSearchParameters, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurence] {
        guard let content = NSString(data: data, encoding: NSUTF8StringEncoding) else {
            return []
        }
        return search(content, parameters, scope)
    }

    private func search(_ content: NSString, _ parameters: ConsoleSearchParameters, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurence] {
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

            var prefix = ""
            if lineRange.length > 300, range.location - contextRange.location > 16 {
                contextRange.length -= (range.location - contextRange.location - 16)
                contextRange.location = range.location - 16
                prefix = "…"
            }
            contextRange.length = min(contextRange.length, 500)

            let previewText = (prefix + line.substring(with: contextRange))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            var preview = AttributedString(previewText, attributes: AttributeContainer(helper.attributes(role: .body2, style: .monospaced)))
            if let range = preview.range(of: parameters.searchTerm, options: .init(parameters.options)) {
                preview[range].foregroundColor = .orange
            }

            let occurence = ConsoleSearchOccurence(
                scope: scope,
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
    let scope: ConsoleSearchScope
    let line: Int
    let range: NSRange
    let text: AttributedString
    let searchContext: RichTextViewModel.SearchContext
}

struct ConsoleSearchParameters: Equatable, Hashable, Codable {
    let searchTerm: String
    let tokens: [ConsoleSearchToken]
    let options: StringSearchOptions

    var filters: [ConsoleSearchFilter] {
        tokens.compactMap {
            guard case .filter(let filter) = $0 else { return nil }
            return filter
        }
    }

    var scopes: [ConsoleSearchScope] {
        let scopes: [ConsoleSearchScope] = tokens.compactMap {
            guard case .scope(let scope) = $0 else { return nil }
            return scope
        }
        return scopes.isEmpty ? ConsoleSearchScope.allCases : scopes
    }
}
