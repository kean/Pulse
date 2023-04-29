// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, *)
protocol ConsoleSearchOperationDelegate: AnyObject {
    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel])
    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool)
}

@available(iOS 15, *)
final class ConsoleSearchOperation {
    private let parameters: ConsoleSearchParameters
    private var entities: [NSManagedObject]
    private var objectIDs: [NSManagedObjectID]
    private var index = 0
    private var cutoff = 10
    private let service: ConsoleSearchService
    private let context: NSManagedObjectContext
    private let lock: os_unfair_lock_t
    private var _isCancelled = false

    private let hasLogFilters: Bool
    private let hasNetworkFilers: Bool

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

        self.hasLogFilters = parameters.filters.contains { $0.filter is (any ConsoleSearchLogFilterProtocol) }
        self.hasNetworkFilers = parameters.filters.contains { $0.filter is (any ConsoleSearchNetworkFilterProtocol) }

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
            guard !hasNetworkFilers else { return nil }
            return _search(message, parameters: parameters)
        case .task(let task):
            guard !hasLogFilters else { return nil }
            return _search(task, parameters: parameters)
        }
    }

    // MARK: Search (LoggerMessageEntity)

    private func _search(_ message: LoggerMessageEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        guard isMatching(message, filters: parameters.filters) else {
            return nil
        }
        guard !parameters.terms.isEmpty else {
            return []
        }
        return search(in: message, parameters: parameters)
    }

    private func isMatching(_ message: LoggerMessageEntity, filters: [ConsoleSearchFilter]) -> Bool {
        Dictionary(grouping: filters.map(\.filter), by: \.name)
            .compactMap { $0.value as? ([any ConsoleSearchLogFilterProtocol]) }
            .allSatisfy { filters in
                filters.contains { $0.isMatch(message) }
            }
    }

    private func search(in message: LoggerMessageEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        var occurrences: [ConsoleSearchOccurrence] = []
        let scopes = parameters.scopes.isEmpty ? ConsoleSearchScope.allCases : parameters.scopes
        for scope in scopes {
            switch scope {
            case .message:
                occurrences += ConsoleSearchOperation.search(message.text, parameters, .message)
            case .metadata:
                occurrences += ConsoleSearchOperation.search(message.rawMetadata, parameters, .metadata)
            default:
                break
            }
        }
        return occurrences.isEmpty ? nil : occurrences
    }

    // MARK: Search (NetworkTaskEntity)

    private func _search(_ task: NetworkTaskEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        guard isMatching(task, filters: parameters.filters) else {
            return nil
        }
        guard !parameters.terms.isEmpty else {
            return []
        }
        return search(in: task, parameters: parameters)
    }

    private func isMatching(_ task: NetworkTaskEntity, filters: [ConsoleSearchFilter]) -> Bool {
        Dictionary(grouping: filters.map(\.filter), by: \.name)
            .compactMap { $0.value as? ([any ConsoleSearchNetworkFilterProtocol]) }
            .allSatisfy { filters in
                filters.contains { $0.isMatch(task) }
            }
    }

    private func search(in task: NetworkTaskEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        var occurrences: [ConsoleSearchOccurrence] = []
        let scopes = parameters.scopes.isEmpty ? ConsoleSearchScope.allCases : parameters.scopes
        for scope in scopes {
            switch scope {
            case .url:
                if var components = URLComponents(string: task.url ?? "") {
                    components.queryItems = nil
                    if let url = components.url?.absoluteString {
                        occurrences += ConsoleSearchOperation.search(url, parameters, scope)
                    }
                }
            case .originalRequestHeaders:
                if let headers = task.originalRequest?.httpHeaders {
                    occurrences += ConsoleSearchOperation.search(headers, parameters, scope)
                }
            case .currentRequestHeaders:
                if let headers = task.currentRequest?.httpHeaders {
                    occurrences += ConsoleSearchOperation.search(headers, parameters, scope)
                }
            case .requestBody:
                if let string = task.requestBody.flatMap(service.getBodyString) {
                    occurrences += ConsoleSearchOperation.search(string, parameters, scope)
                }
            case .responseHeaders:
                if let headers = task.response?.httpHeaders {
                    occurrences += ConsoleSearchOperation.search(headers, parameters, scope)
                }
            case .responseBody:
                if let string = task.responseBody.flatMap(service.getBodyString) {
                    occurrences += ConsoleSearchOperation.search(string, parameters, scope)
                }
            case .message, .metadata:
                break // Applies only to LoggerMessageEntity
            }
        }
        return occurrences.isEmpty ? nil : occurrences
    }

    private static  func search(_ data: Data, _ parameters: ConsoleSearchParameters, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurrence] {
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }
        return search(content, parameters, scope)
    }

    private static func search(_ content: String, _ parameters: ConsoleSearchParameters, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurrence] {
        var remainingMatchedTerms = Set(parameters.terms)
        var matches: [ConsoleSearchMatch] = []
        var lineCount = 0
        content.enumerateLines { line, stop in
            lineCount += 1
            for term in parameters.terms {
                for range in line.ranges(of: term.text, options: term.options) {
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

struct ConsoleSearchMatch {
    let line: String
    /// Starts with `1.
    let lineNumber: Int
    let range: Range<String.Index>
    let term: ConsoleSearchTerm

    static let limit = 1000
}

@available(iOS 15, *)
final class ConsoleSearchService {
    private let cache = NSCache<NSManagedObjectID, CachedString>()

    init() {
        cache.totalCostLimit = 16_000_000
        cache.countLimit = 1000
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    func getBodyString(for blob: LoggerBlobHandleEntity) -> String? {
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
