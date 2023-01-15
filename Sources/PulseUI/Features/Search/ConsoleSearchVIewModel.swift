// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchViewModel: ObservableObject {
    // TODO: add actual search
    private let entities: [NSManagedObject]

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []
    @Published var searchText: String = ""
    @Published var isSearching = false

    @State var tokens: [String] = []

    // TODO: implement suggested tokens
    // TODO: for status code allow ranges (400<500) etc
    // TODO: use new Regex for this
    var suggestedTokens: [String] {
        if searchText == "201" {
            return ["Status Code 200"]
        }
        return ["Status Code 500", "application/json"]
    }

    private let search = ConsoleSearchService()

    private var cancellables: [AnyCancellable] = []
    private let context: NSManagedObjectContext

    init(entities: [NSManagedObject], store: LoggerStore) {
        self.entities = entities
        self.context = store.newBackgroundContext()

        // TODO: cancel previous search?
        // TODO: use previous results for more specific searches
        $searchText.dropFirst().sink { [weak self] in
            self?.search($0)
        }.store(in: &cancellables)
    }

    private func search(_ searchText: String) {
        guard !isSearching else { return }

        guard searchText.count > 1 else {
            results = []
            return
        }

        isSearching = true

        // TODO: keep previous matches when more speicifc searc is added
        results = []

        context.perform {
            self.search(searchText, in: self.entities.map(\.objectID))
        }
    }

    // TODO: add a switch in UI to enable regex and other options?
    private func search(_ searchText: String, in objectIDs: [NSManagedObjectID]) {
        for objectID in objectIDs {
            if let entity = try? self.context.existingObject(with: objectID),
               let result = self.search(searchText, in: entity) {
                DispatchQueue.main.async {
                    self.results.append(result)
                }
            }
        }
        DispatchQueue.main.async {
            self.didFinishSearch(with: searchText)
        }
    }

    private func didFinishSearch(with searchText: String) {
        isSearching = false

        if searchText != self.searchText {
            search(self.searchText)
        }
    }

    // TOOD: dynamic cast
    private func search(_ searchText: String, in entity: NSManagedObject) -> ConsoleSearchResultViewModel? {
        guard let task = (entity as? LoggerMessageEntity)?.task else {
            return nil
        }
        Thread.sleep(forTimeInterval: 1)
        return search(searchText, in: task)
    }

    // TODO: use on TextHelper instance
    // TODO: add remaining fields
    // TODO: what if URL matches? can we highlight the cell itself?
    private func search(_ searchText: String, in task: NetworkTaskEntity) -> ConsoleSearchResultViewModel? {
        var occurences: [ConsoleSearchOccurence] = []
        occurences += search.search(.responseBody, in: task, searchText: searchText, options: .default)
        guard !occurences.isEmpty else {
            return nil
        }
        // TODO: remove sort (or how do we sort?)
        return ConsoleSearchResultViewModel(entity: task, occurences: occurences)
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
