// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchViewModel: ObservableObject, ConsoleSearchOperationDelegate {
    private let entities: [NSManagedObject]
    private let objectIDs: [NSManagedObjectID]

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []
    private var buffer: [ConsoleSearchResultViewModel] = []
    @Published var searchText: String = ""
    @Published var isSpinnerNeeded = false
    @Published var isSearching = false
    @Published var hasMore = false

    private var dirtyDate: Date?
    private var operation: ConsoleSearchOperation?

    @State var tokens: [String] = []

    // TODO: implement suggested tokens
    // TODO: for status code allow ranges (400<500) etc
    // TODO: use new Regex for this
    // TODO: why I can't search for '"'?
    var suggestedTokens: [String] {
        if searchText == "201" {
            return ["Status Code 200"]
        }
        return ["Status Code 500", "application/json"]
    }

    private let service = ConsoleSearchService()

    private var cancellables: [AnyCancellable] = []
    private let context: NSManagedObjectContext

    init(entities: [NSManagedObject], store: LoggerStore) {
        self.entities = entities
        self.objectIDs = entities.map(\.objectID)
        self.context = store.newBackgroundContext()

        $searchText.dropFirst().sink { [weak self] in
            self?.didUpdateSearchCriteria($0)
        }.store(in: &cancellables)

        $isSearching
            .removeDuplicates()
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.isSpinnerNeeded = $0 }
            .store(in: &cancellables)
    }

    private func didUpdateSearchCriteria(_ searchText: String) {
        operation?.cancel()
        operation = nil

        guard searchText.count > 1 else {
            isSearching = false
            results = []
            return
        }

        isSearching = true
        buffer = []

        // We want to continue showing old results for just a little bit longer
        // to prevent screen from flickering. If the search is slow, we'll just
        // remove the results eventually.
        if !results.isEmpty {
            dirtyDate = Date()
        }

        let operation = ConsoleSearchOperation(objectIDs: objectIDs, searchText: searchText, service: service, context: context)
        operation.delegate = self
        operation.resume()
        self.operation = operation
    }

    func buttonShowMoreResultsTapped() {
        isSearching = true
        operation?.resume()
    }

    // MARK: ConsoleSearchOperationDelegate

    fileprivate func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel]) {
        guard self.operation === operation else { return }

        if let dirtyDate = dirtyDate {
            self.buffer += results
            if Date().timeIntervalSince(dirtyDate) > 0.05 {
                self.dirtyDate = nil
                self.results = buffer
                self.buffer = []
            }
        } else {
            self.results += results
        }
    }

    fileprivate func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool) {
        guard self.operation === operation else { return }

        isSearching = false
        if dirtyDate != nil {
            self.dirtyDate = nil
            self.results = buffer
        }
        self.hasMore = hasMore
    }
}

@available(iOS 15, tvOS 15, *)
private protocol ConsoleSearchOperationDelegate: AnyObject { // Going old-school
    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel])
    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool)
}

@available(iOS 15, tvOS 15, *)
private final class ConsoleSearchOperation {
    private let searchText: String
    private var objectIDs: [NSManagedObjectID]
    private var index = 0
    private var cutoff = 10
    private let service: ConsoleSearchService
    private let context: NSManagedObjectContext
    private let lock: os_unfair_lock_t
    private var _isCancelled = false

    weak var delegate: ConsoleSearchOperationDelegate?

    init(objectIDs: [NSManagedObjectID],
         searchText: String,
         service: ConsoleSearchService,
         context: NSManagedObjectContext) {
        self.objectIDs = objectIDs
        self.searchText = searchText
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
            if let entity = try? self.context.existingObject(with: objectIDs[index]),
               let result = self.search(searchText, in: entity) {
                found += 1
                if found > cutoff {
                    hasMore = true
                    index -= 1
                } else {
                    DispatchQueue.main.async {
                        self.delegate?.searchOperation(self, didAddResults: [result])
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

    // TOOD: dynamic cast
    private func search(_ searchText: String, in entity: NSManagedObject) -> ConsoleSearchResultViewModel? {
        guard let task = (entity as? LoggerMessageEntity)?.task else {
            return nil
        }
        return search(searchText, in: task)
    }

    // TODO: use on TextHelper instance
    // TODO: add remaining fields
    // TODO: what if URL matches? can we highlight the cell itself?
    private func search(_ searchText: String, in task: NetworkTaskEntity) -> ConsoleSearchResultViewModel? {
        var occurences: [ConsoleSearchOccurence] = []
        occurences += service.search(.responseBody, in: task, searchText: searchText, options: .default)
        guard !occurences.isEmpty else {
            return nil
        }
        return ConsoleSearchResultViewModel(entity: task, occurences: occurences)
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

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchService {

    // TODO: prioritize full matches
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
                occurrence: preview,
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
    // TODO: display line number + offset
    let line: Int
    let range: NSRange
    // TODO: rename?
    let occurrence: AttributedString
    let searchContext: RichTextViewModel.SearchContext
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultViewModel: Identifiable {
    var id: NSManagedObjectID { entity.objectID }
    let entity: NSManagedObject
    let occurences: [ConsoleSearchOccurence]
}
