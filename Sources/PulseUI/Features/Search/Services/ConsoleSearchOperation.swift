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
        occurrences += PulseUI.search(message.text as NSString, parameters, .message)
        occurrences += PulseUI.search(message.rawMetadata as NSString, parameters, .metadata)
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
                        occurrences += PulseUI.search(url as NSString, parameters, scope)
                    }
                }
            case .originalRequestHeaders:
                if let headers = task.originalRequest?.httpHeaders {
                    occurrences += PulseUI.search(headers as NSString, parameters, scope)
                }
            case .currentRequestHeaders:
                if let headers = task.currentRequest?.httpHeaders {
                    occurrences += PulseUI.search(headers as NSString, parameters, scope)
                }
            case .requestBody:
                if let string = task.requestBody.flatMap(service.getBodyString) {
                    occurrences += PulseUI.search(string, parameters, scope)
                }
            case .responseHeaders:
                if let headers = task.response?.httpHeaders {
                    occurrences += PulseUI.search(headers as NSString, parameters, scope)
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
        guard let content = NSString(data: data, encoding: NSUTF8StringEncoding) else {
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
    _ content: NSString,
    _ parameters: ConsoleSearchParameters,
    _ scope: ConsoleSearchScope
) -> [ConsoleSearchOccurrence] {
    let matchAttributes = TextHelper().attributes(role: .body2, style: .monospaced)
    var matchedTerms: Set<ConsoleSearchTerm> = []

    struct Match {
        let line: NSString
        let lineNumber: Int
        let range: NSRange
        let term: ConsoleSearchTerm
    }

    var allMatches: [(line: NSString, lineNumber: Int, range: NSRange, term: ConsoleSearchTerm)] = []
    var lineCount = 0
    content.enumerateLines { line, stop in
        lineCount += 1
        let line = line as NSString
        for term in parameters.terms {
            let matches = line.ranges(of: term.text, options: term.options)
            for range in matches {
                allMatches.append((line, lineCount, range, term))
            }
            if !matches.isEmpty {
                matchedTerms.insert(term)
            }
        }
    }

    guard matchedTerms.count == Set(parameters.terms).count else {
        return [] // Has to match all
    }

    var occurrences: [ConsoleSearchOccurrence] = []
    var matchIndex = 0
    for (line, lineNumber, range, term) in allMatches {
        let lineRange = lineCount == 1 ? NSRange(location: 0, length: content.length) :  (line.getLineRange(range) ?? range) // Optimization for long lines

        var prefixRange = NSRange(location: lineRange.location, length: range.location - lineRange.location)
        var suffixRange = NSRange(location: range.upperBound, length: lineRange.upperBound - range.upperBound)


        // Reduce context to a reasonable size
        var needsPrefixEllipsis = false
        if prefixRange.length > 30 {
            let distance = prefixRange.length - 30
            prefixRange.length = 30
            prefixRange.location += distance
            needsPrefixEllipsis = true
        }
        suffixRange.length = min(120, suffixRange.length)

        // Trim whitespace and some punctuation characters from the end of the string
        while prefixRange.location < range.location, shouldTrimCharacter(line.character(at: prefixRange.location)) {
            prefixRange.location += 1
            prefixRange.length -= 1
        }
        while (suffixRange.upperBound - 1) > range.location, shouldTrimCharacter(line.character(at: (suffixRange.upperBound - 1))) {
            suffixRange.length -= 1
        }

        // Try to trim the prefix at the start of the word
        while prefixRange.location > 0,
              let character = Character(line.character(at: prefixRange.location)),
              !character.isWhitespace,
              prefixRange.length < 50 {
            prefixRange.location -= 1
            prefixRange.length += 1
        }

        let attributes = AttributeContainer(matchAttributes)
        let prefix = AttributedString((needsPrefixEllipsis ? "…" : "") + line.substring(with: prefixRange), attributes: attributes)
        var match = AttributedString(line.substring(with: range), attributes: attributes)
        match.foregroundColor = .orange
        let suffix = AttributedString(line.substring(with: suffixRange), attributes: attributes)
        let preview = prefix + match + suffix

        let occurrence = ConsoleSearchOccurrence(
            scope: scope,
            line: lineNumber,
            range: range,
            text: preview,
            searchContext: .init(searchTerm: term, matchIndex: matchIndex)
        )
        occurrences.append(occurrence)

        matchIndex += 1
    }

    return occurrences
}

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchService {
    private let cachedBodies = Cache<NSManagedObjectID, NSString>(costLimit: 16_000_000, countLimit: 1000)

    func getBodyString(for blob: LoggerBlobHandleEntity) -> NSString? {
        if let string = cachedBodies.value(forKey: blob.objectID)  {
            return string
        }
        guard let data = blob.data,
              let string = NSString(data: data, encoding: NSUTF8StringEncoding)
        else {
            return nil
        }
        cachedBodies.set(string, forKey: blob.objectID, cost: data.count)
        return string
    }
}

private struct ConsoleSearchContext {

}

private func shouldTrimCharacter(_ character: unichar) -> Bool {
    guard let character = Character(character) else { return true }
    return character.isNewline || character.isWhitespace || character == ","
}

#endif
