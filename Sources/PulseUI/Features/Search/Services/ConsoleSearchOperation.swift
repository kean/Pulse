// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 16, visionOS 1, *)
protocol ConsoleSearchOperationDelegate: AnyObject {
    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel])
    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool)
}

@available(iOS 16, visionOS 1, *)
final class ConsoleSearchOperation {
    private let parameters: ConsoleSearchParameters
    private var entities: [NSManagedObject]
    private var objectIDs: [NSManagedObjectID]
    private var index = 0
    private var cutoff = 12
    private let service: ConsoleSearchService
    private let context: NSManagedObjectContext
    private let lock: os_unfair_lock_t
    private var _isCancelled = false

    weak var delegate: ConsoleSearchOperationDelegate?

    init(entities: [NSManagedObject],
         parameters: ConsoleSearchParameters,
         service: ConsoleSearchService,
         context: NSManagedObjectContext) {
        self.entities = entities
        self.objectIDs = entities.map(\.objectID)
        self.parameters = parameters
        self.service = service
        self.context = context

        self.lock = .allocate(capacity: 1)
        self.lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func resume() {
        context.perform { self._start() }
    }

    private func _start() {
        var found = 0
        var hasMore = false
        while index < objectIDs.count, !isCancelled, !hasMore {
            let currentMatchIndex = index
            if let entity = try? self.context.existingObject(with: objectIDs[index]),
               let occurrences = self.search(entity, parameters: parameters) {
                found += 1
                if found > cutoff {
                    hasMore = true
                    index -= 1
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.searchOperation(self, didAddResults: [ConsoleSearchResultViewModel(entity: self.entities[currentMatchIndex], occurrences: occurrences)])
                    }
                }
            }
            index += 1
        }
        DispatchQueue.main.async {
            self.delegate?.searchOperationDidFinish(self, hasMore: hasMore)
            if self.cutoff < 1000 {
                self.cutoff *= 2
            }
        }
    }

    // MARK: Search

    func search(_ entity: NSManagedObject, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        guard !parameters.isEmpty else {
            return nil
        }
        switch LoggerEntity(entity) {
        case .message(let message):
            return _search(message, parameters: parameters)
        case .task(let task):
            return _search(task, parameters: parameters)
        }
    }

    // MARK: Search (LoggerMessageEntity)

    private func _search(_ message: LoggerMessageEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        guard let term = parameters.term else {
            return []
        }
        var occurrences: [ConsoleSearchOccurrence] = []
        let scopes = parameters.scopes.isEmpty ? ConsoleSearchScope.allCases : parameters.scopes
        for scope in scopes {
            switch scope {
            case .message:
                occurrences += ConsoleSearchOperation.search(message.text, term, .message)
            case .metadata:
                occurrences += ConsoleSearchOperation.search(message.rawMetadata, term, .metadata)
            default:
                break
            }
        }
        return occurrences.isEmpty ? nil : occurrences
    }

    // MARK: Search (NetworkTaskEntity)

    private func _search(_ task: NetworkTaskEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        guard let term = parameters.term else {
            return []
        }
        var occurrences: [ConsoleSearchOccurrence] = []
        let scopes = parameters.scopes.isEmpty ? ConsoleSearchScope.allCases : parameters.scopes
        for scope in scopes {
            switch scope {
            case .url:
                if var components = URLComponents(string: task.url ?? "") {
                    components.queryItems = nil
                    if let url = components.url?.absoluteString {
                        occurrences += ConsoleSearchOperation.search(url, term, scope)
                    }
                }
            case .requestBody:
                if let string = task.requestBody.flatMap(service.getBodyString) {
                    occurrences += ConsoleSearchOperation.search(string, term, scope)
                }
            case .originalRequestHeaders:
                if let headers = task.originalRequest?.httpHeaders {
                    occurrences += ConsoleSearchOperation.search(headers, term, scope)
                }
            case .currentRequestHeaders:
                if let headers = task.currentRequest?.httpHeaders {
                    occurrences += ConsoleSearchOperation.search(headers, term, scope)
                }
            case .responseBody:
                if let string = task.responseBody.flatMap(service.getBodyString) {
                    occurrences += ConsoleSearchOperation.search(string, term, scope)
                }
            case .responseHeaders:
                if let headers = task.response?.httpHeaders {
                    occurrences += ConsoleSearchOperation.search(headers, term, scope)
                }
            case .message, .metadata:
                break // Applies only to LoggerMessageEntity
            }
        }
        return occurrences.isEmpty ? nil : occurrences
    }

    private static  func search(_ data: Data, _ term: ConsoleSearchTerm, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurrence] {
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }
        return search(content, term, scope)
    }

    private static func search(_ content: String, _ term: ConsoleSearchTerm, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurrence] {
        var matches: [ConsoleSearchMatch] = []
        var lineCount = 0
        content.enumerateLines { line, stop in
            lineCount += 1
            for range in line.ranges(of: term.text, options: term.options, limit: ConsoleSearchMatch.limit) {
                let match = ConsoleSearchMatch(line: line, lineNumber: lineCount, range: range, term: term)
                matches.append(match)
            }
            if matches.count > ConsoleSearchMatch.limit {
                stop = true
            }
        }
        return zip(matches.indices, matches).map { (index, match) in
            ConsoleSearchOccurrence(scope: scope, match: match, searchContext: .init(searchTerm: match.term, matchIndex: index))
        }
    }

    // MARK: Cancellation

    private var isCancelled: Bool {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return _isCancelled
    }

    func cancel() {
        os_unfair_lock_lock(lock)
        _isCancelled = true
        os_unfair_lock_unlock(lock)
    }
}

package struct ConsoleSearchMatch {
    package let line: String
    /// Starts with `1.
    package let lineNumber: Int
    package let range: Range<String.Index>
    package let term: ConsoleSearchTerm

    package static let limit = 6

    package init(line: String, lineNumber: Int, range: Range<String.Index>, term: ConsoleSearchTerm) {
        self.line = line
        self.lineNumber = lineNumber
        self.range = range
        self.term = term
    }
}

@available(iOS 16, visionOS 1, *)
package final class ConsoleSearchService {
    private let cache = NSCache<NSManagedObjectID, CachedString>()

    package init() {
        cache.totalCostLimit = 16_000_000
        cache.countLimit = 1000
    }

    package func clearCache() {
        cache.removeAllObjects()
    }

    package func getBodyString(for blob: LoggerBlobHandleEntity) -> String? {
        if let string = cache.object(forKey: blob.objectID)?.value {
            return string
        }
        guard let data = blob.data, let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        cache.setObject(.init(value: string), forKey: blob.objectID, cost: data.count)
        return string
    }
}

/// Wrapping it in a class to make it compatible with `NSCache`.
private final class CachedString {
    let value: String
    init(value: String) { self.value = value }
}

#endif
