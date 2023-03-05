// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
protocol ConsoleSearchOperationDelegate: AnyObject {
    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel])
    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool)
}

@available(iOS 15, tvOS 15, *)
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
        switch LoggerEntity(entity) {
        case .message(let message):
            return _search(message, parameters: parameters)
        case .task(let task):
            return _search(task, parameters: parameters)
        }
    }

    private func _search(_ message: LoggerMessageEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        var occurrences: [ConsoleSearchOccurrence] = []
        occurrences += PulseUI.search(message.text, parameters, .message)
        occurrences += PulseUI.search(message.rawMetadata, parameters, .metadata)
        return occurrences.isEmpty ? nil : occurrences
    }

    private func _search(_ task: NetworkTaskEntity, parameters: ConsoleSearchParameters) -> [ConsoleSearchOccurrence]? {
        guard !parameters.isEmpty else {
            return nil
        }
        guard isMatching(task, filters: parameters.filters) else {
            return nil
        }
        guard !parameters.terms.isEmpty else {
            return []
        }
        return search(in: task, parameters: parameters)
    }

    private func isMatching(_ task: NetworkTaskEntity, filters: [ConsoleSearchFilter]) -> Bool {
        let groups = Dictionary(grouping: filters, by: { $0.filter.name })
        for (_, filters) in groups {
            if !filters.contains(where: { $0.filter.isMatch(task) }) {
                return false
            }
        }
        return true
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
                        occurrences += PulseUI.search(url, parameters, scope)
                    }
                }
            case .originalRequestHeaders:
                if let headers = task.originalRequest?.httpHeaders {
                    occurrences += PulseUI.search(headers, parameters, scope)
                }
            case .currentRequestHeaders:
                if let headers = task.currentRequest?.httpHeaders {
                    occurrences += PulseUI.search(headers, parameters, scope)
                }
            case .requestBody:
                if let string = task.requestBody.flatMap(service.getBodyString) {
                    occurrences += PulseUI.search(string, parameters, scope)
                }
            case .responseHeaders:
                if let headers = task.response?.httpHeaders {
                    occurrences += PulseUI.search(headers, parameters, scope)
                }
            case .responseBody:
                if let string = task.responseBody.flatMap(service.getBodyString) {
                    occurrences += PulseUI.search(string, parameters, scope)
                }
            case .message, .metadata:
                break // Applies only to LoggerMessageEntity
            }
        }
        return occurrences.isEmpty ? nil : occurrences
    }

    private func search(_ data: Data, _ parameters: ConsoleSearchParameters, _ scope: ConsoleSearchScope) -> [ConsoleSearchOccurrence] {
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }
        return PulseUI.search(content, parameters, scope)
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

@available(iOS 15, macOS 13, *)
private func search(
    _ content: String,
    _ parameters: ConsoleSearchParameters,
    _ scope: ConsoleSearchScope
) -> [ConsoleSearchOccurrence] {
    let matchAttributes = TextHelper().attributes(role: .body2, style: .monospaced)
    var matchedTerms: Set<ConsoleSearchTerm> = []
    var allMatches: [ConsoleSearchMatch] = []
    var lineCount = 0
#warning("TODO: use stop when too many matches")
    content.enumerateLines { line, stop in
        lineCount += 1
        for term in parameters.terms {
            let matches = line.ranges(of: term.text, options: term.options)
            for range in matches {
                let match = ConsoleSearchMatch(line: line, lineNumber: lineCount, range: range, term: term)
                allMatches.append(match)
            }
            if !matches.isEmpty {
                matchedTerms.insert(term)
            }
        }
    }

    guard matchedTerms.count == Set(parameters.terms).count else {
        return [] // Has to match all
    }

    return zip(allMatches.indices, allMatches).map { (index, match) in
        ConsoleSearchOccurrence(
            scope: scope,
            line: match.lineNumber,
            range: NSRange(location: 0, length: 1),
            text: ConsoleSearchOperation.makePreview(for: match, attributes: matchAttributes),
            searchContext: .init(searchTerm: match.term, matchIndex: index)
        )
    }
}

@available(iOS 15, macOS 13, *)
extension ConsoleSearchOperation {
#warning("move this to ViewModel?")
    static func makePreview(for match: ConsoleSearchMatch, attributes customAttributes: [NSAttributedString.Key: Any] = [:]) -> AttributedString {

        let prefixStartIndex = match.line.index(match.range.lowerBound, offsetBy: -50, limitedBy: match.line.startIndex) ?? match.line.startIndex
        let prefixRange = prefixStartIndex..<match.range.lowerBound

#warning("increase count?")
        let suffixUpperBound = match.line.index(match.range.upperBound, offsetBy: 120, limitedBy: match.line.endIndex) ?? match.line.endIndex
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

#warning("TEMP")
struct ConsoleSearchMatch {
    let line: String
    /// Starts with `1.
    let lineNumber: Int
    let range: Range<String.Index>
    let term: ConsoleSearchTerm
}

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchService {
    private let cachedBodies = Cache<NSManagedObjectID, String>(costLimit: 16_000_000, countLimit: 1000)

    func getBodyString(for blob: LoggerBlobHandleEntity) -> String? {
        if let string = cachedBodies.value(forKey: blob.objectID)  {
            return string
        }
        guard let data = blob.data,
              let string = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        cachedBodies.set(string, forKey: blob.objectID, cost: data.count)
        return string
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

#endif
