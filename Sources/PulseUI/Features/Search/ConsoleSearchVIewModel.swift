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

    private let search = ConsoleSearchService()

    private var cancellables: [AnyCancellable] = []

    init(entities: [NSManagedObject]) {
        self.entities = entities

        // TODO: should be empty by default + show nice placeholder
        self.results = entities.map {
            ConsoleSearchResultViewModel(entity: $0, occurences: [])
        }

        // TODO: add debouce, etc
        $searchText.dropFirst().sink { [weak self] in
            self?.search($0)
        }.store(in: &cancellables)

        #warning("TEPM")
        DispatchQueue.main.async {
            self.searchText = "Nuke"
        }
    }

    // TODO: perform in background
    private func search(_ searchText: String) {
        guard searchText.count > 1 else {
            // TODO: prompt and exlain how to search
            self.results = []
            return
        }
        // TODO: add a switch in UI to enable regex and other options?
        var results: [ConsoleSearchResultViewModel] = []
        // TODO: proper dynamic cast
        for entity in entities as! [LoggerMessageEntity] {
            if let task = entity.task, let result = search(searchText: searchText, in: task) {
                results.append(result)
            }
        }
        self.results = results
    }

    // TODO: syntax highliughting?
    // TODO: use on TextHelper instance
    // TODO: add remaining fields
    // TODO: what if URL matches? can we highlight the cell itself?
    private func search(searchText: String, in task: NetworkTaskEntity) -> ConsoleSearchResultViewModel? {
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
