// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    var body: some View {
        List {
            ForEach(viewModel.results) { result in
                Section {
                    ConsoleEntityCell(entity: result.entity)
                    // TODO: limit number of occurences of the same type (or only have one and display how many more?)
                    // TODO: when open body, start with a search term immediatelly
                    let occurences = Array(result.occurences.enumerated())
                    ForEach(occurences.prefix(3), id: \.offset) { item in
                        NavigationLink(destination: makeDestination(for: item.element.kind, entity: result.entity)) {
                            makeCell(for: item.element)
                        }
                    }
                    if occurences.count > 3 {
                        NavigationLink(destination: Text("Show All")) {
                            Text("Show All Occurences") + Text(" (\(occurences.count))").foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.searchText)
    }

    // TODO: add occurence IDs instead of indices
    func makeCell(for occurence: ConsoleSearchOccurence) -> some View {
        NavigationLink(destination: Text("Placeholder")) {
            // TODO: handle errors
            let attr = try! AttributedString(occurence.occurrence, including: \.uiKit)
            VStack(alignment: .leading, spacing: 4) {
                Text(occurence.kind.title + " (Line: \(occurence.line):\(occurence.range.lowerBound))")
                    .font(ConsoleConstants.fontTitle)
                    .foregroundColor(.secondary)
                Text(attr)
                    .lineLimit(3)
            }
        }
    }

    func makeDestination(for kind: ConsoleSearchOccurence.Kind, entity: NSManagedObject) -> some View {
        switch kind {
        case .responseBody:
            return NetworkInspectorResponseBodyView(viewModel: .init(task: entity as! NetworkTaskEntity))
        }
    }
}

final class ConsoleSearchViewModel: ObservableObject {
    // TODO: add actual search
    private let entities: [NSManagedObject]

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []
    @Published var searchText: String = ""

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
    }

    // TODO: perform in background
    private func search(_ searchText: String) {
        guard searchText.count > 1 else {
            // TODO: prompt and exlain how to search
            self.results = []
            return
        }
        // TODO: add a switch in UI to enable regex and other options?
        // TODO: handle errors
        let regex = try! Regex(searchText)
        var results: [ConsoleSearchResultViewModel] = []
        // TODO: proper dynamic cast
        for entity in entities as! [LoggerMessageEntity] {
            if let task = entity.task, let result = search(regex, searchText: searchText, in: task) {
                results.append(result)
            }
        }
        self.results = results
    }

    // TODO: syntax highliughting?
    // TODO: use on TextHelper instance
    // TODO: add remaining fields
    // TODO: what if URL matches? can we highlight the cell itself?
    private func search(_ regex: Regex, searchText: String, in task: NetworkTaskEntity) -> ConsoleSearchResultViewModel? {
        var occurences: [ConsoleSearchOccurence] = []
        if let responseBody = task.responseBody?.data, let string = String(data: responseBody, encoding: .utf8) {
            let matches = regex.matches(in: string)
            for match in matches {
                let range = match.fullMatch.startIndex..<match.fullMatch.endIndex
                // TODO: check range limits
                // TODO: find next and current line + adjust to fit current line on screen
                let contextRange = string.index(range.lowerBound, offsetBy: -20)..<string.index(range.upperBound, offsetBy: 30)
                // TODO: better highlight for found?
                let substring = NSMutableAttributedString(attributedString:  TextRenderer(options: .sharing).preformatted(string.substring(with: contextRange).trimmingCharacters(in: .whitespacesAndNewlines)))

                if let range = substring.string.firstRange(of: searchText) {
                    substring.addAttribute(.foregroundColor, value: UXColor.systemOrange, range: NSRange(range, in: substring.string))
                }

                // TODO: optimize + show line number
                let range2 = Int.random(in: 1...50)..<200
                let occurence = ConsoleSearchOccurence(
                    kind: .responseBody,
                    line: .random(in: 1...100),
                    range: range2,
                    occurrence: substring
                )
                occurences.append(occurence)
            }
        }
        guard !occurences.isEmpty else {
            return nil
        }
        // TODO: remove sort (or how do we sort?)
        return ConsoleSearchResultViewModel(entity: task, occurences: occurences)
    }
}

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
    let range: Range<Int>
    let occurrence: NSAttributedString
}

struct ConsoleSearchResultViewModel: Identifiable {
    var id: NSManagedObjectID { entity.objectID }
    let entity: NSManagedObject
    let occurences: [ConsoleSearchOccurence]
}

#if DEBUG
@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleSearchView(viewModel: .init(entities: try! LoggerStore.mock.allMessages()))
        }
    }
}
#endif
