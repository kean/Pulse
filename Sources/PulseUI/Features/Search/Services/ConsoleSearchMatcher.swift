// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import Pulse
import CoreData

package enum ConsoleSearchMatcher {
    /// Synchronously searches `entity` for the given parameters. Must be
    /// invoked from the managed object context's queue.
    package static func search(_ entity: NSManagedObject, parameters: ConsoleSearchParameters, service: ConsoleSearchService) -> [ConsoleSearchOccurrence]? {
        guard !parameters.isEmpty else { return nil }
        switch LoggerEntity(entity) {
        case .message(let message):
            return search(message, parameters: parameters)
        case .task(let task):
            return search(task, parameters: parameters, service: service)
        }
    }

    private static func search(_ message: LoggerMessageEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        guard !parameters.terms.isEmpty else { return [] }
        var occurrences: [ConsoleSearchOccurrence] = []
        for scope in parameters.scopes {
            switch scope {
            case .message:
                occurrences += search(message.text, parameters, .message)
            case .metadata:
                occurrences += search(message.rawMetadata, parameters, .metadata)
            default:
                break
            }
        }
        return occurrences.isEmpty ? nil : occurrences
    }

    private static func search(_ task: NetworkTaskEntity, parameters: ConsoleSearchParameters, service: ConsoleSearchService) -> [ConsoleSearchOccurrence]? {
        guard !parameters.terms.isEmpty else { return [] }
        var occurrences: [ConsoleSearchOccurrence] = []
        for scope in parameters.scopes {
            switch scope {
            case .url:
                // Search the URL without its query string. The query string is its
                // own scope so users can opt in or out of it independently.
                if var components = URLComponents(string: task.url ?? "") {
                    components.queryItems = nil
                    if let url = components.url?.absoluteString {
                        occurrences += search(url, parameters, scope)
                    }
                }
            case .query:
                if let urlString = task.url,
                   let components = URLComponents(string: urlString),
                   let query = components.query {
                    occurrences += search(query, parameters, scope)
                }
            case .requestHeaders:
                let original = task.originalRequest?.httpHeaders
                if let original = original {
                    occurrences += search(original, parameters, scope)
                }
                if let current = task.currentRequest?.httpHeaders, current != original {
                    occurrences += search(current, parameters, scope)
                }
            case .requestBody:
                if let string = task.requestBody.flatMap(service.getBodyString) {
                    occurrences += search(string, parameters, scope)
                }
            case .responseHeaders:
                if let headers = task.response?.httpHeaders {
                    occurrences += search(headers, parameters, scope)
                }
            case .responseBody:
                if let string = task.responseBody.flatMap(service.getBodyString) {
                    occurrences += search(string, parameters, scope)
                }
            case .message, .metadata:
                break // Applies only to LoggerMessageEntity
            }
        }
        return occurrences.isEmpty ? nil : occurrences
    }

    private static func search(_ content: String, _ parameters: ConsoleSearchParameters, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurrence] {
        var remainingMatchedTerms = Set(parameters.terms)
        var matches: [ConsoleSearchMatch] = []
        var lineCount = 0
        content.enumerateLines { line, stop in
            lineCount += 1
            for term in parameters.terms {
                for range in line.ranges(of: term.text, options: term.options, limit: ConsoleSearchMatch.limit) {
                    let match = ConsoleSearchMatch(line: line, lineNumber: lineCount, range: range, term: term)
                    matches.append(match)
                }
                if !matches.isEmpty, !remainingMatchedTerms.isEmpty {
                    remainingMatchedTerms.remove(term)
                }
            }
            if matches.count > ConsoleSearchMatch.limit, remainingMatchedTerms.isEmpty {
                stop = true
            }
        }

        guard remainingMatchedTerms.isEmpty else {
            return [] // Has to match all
        }

        return zip(matches.indices, matches).map { (index, match) in
            ConsoleSearchOccurrence(scope: scope, match: match, searchContext: .init(searchTerm: match.term, matchIndex: index))
        }
    }
}

#endif
