// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

final class ConsoleSearchBarViewModel: ObservableObject {
    @Published var text: String = ""
    @Published var tokens: [ConsoleSearchToken] = []
}

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchViewModel: ObservableObject, ConsoleSearchOperationDelegate {
    private var entities: [NSManagedObject]
    private var objectIDs: [NSManagedObjectID]

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []

    @Published var isSpinnerNeeded = false
    @Published var isSearching = false
    @Published var hasMore = false

    // important: if you reload the view with searchable quickly during typing, it crashes and burns
    let searchBar = ConsoleSearchBarViewModel()

    private var dirtyDate: Date?
    private var buffer: [ConsoleSearchResultViewModel] = []
    private var operation: ConsoleSearchOperation?

    @Published var suggestedTokens: [ConsoleSearchSuggestion] = []

    private let service = ConsoleSearchService()

    private var cancellables: [AnyCancellable] = []
    private let context: NSManagedObjectContext

    init(entities: [NSManagedObject], store: LoggerStore) {
        self.entities = entities
        self.objectIDs = entities.map(\.objectID)
        self.context = store.newBackgroundContext()

        let text = searchBar.$text
            .map { $0.trimmingCharacters(in: .whitespaces ) }
            .removeDuplicates()

        Publishers.CombineLatest(text, searchBar.$tokens.removeDuplicates()).sink { [weak self] in
            self?.didUpdateSearchCriteria($0, $1)
            self?.updateSearchTokens(for: $0)
        }.store(in: &cancellables)

        $isSearching
            .removeDuplicates()
            .debounce(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.isSpinnerNeeded = $0 }
            .store(in: &cancellables)
    }

    func setEntities(_ entities: [NSManagedObject]) {
        self.entities = entities
        self.objectIDs = entities.map(\.objectID)
    }

    private func didUpdateSearchCriteria(_ searchText: String, _ tokens: [ConsoleSearchToken]) {
        operation?.cancel()
        operation = nil

        guard searchText.count > 1 || !tokens.isEmpty else {
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

        let operation = ConsoleSearchOperation(objectIDs: objectIDs, searchText: searchText, tokens: tokens, service: service, context: context)
        operation.delegate = self
        operation.resume()
        self.operation = operation
    }

    private func updateSearchTokens(for searchText: String) {
        guard #available(iOS 16, tvOS 16, *) else { return }

#warning("add default suggestions")
        guard !searchText.isEmpty else {
            self.suggestedTokens = []
            return
        }

#warning("easier way to manage these suggestions")
#warning("add suggestions based on input, e.g. input range")
#warning("finish this prototype")
#warning("different styles for filters and completions")
#warning("dont show suggestion when its not specific enough")
#warning("search like in xcode with first letter only")
#warning("make it all case insensitive")
#warning("if you are only entering values, what to suggest?")
#warning("filtes and scopes in separate categories")

        var suggestions: [ConsoleSearchSuggestion] = []

        // Status Code
        if let filter = try? Parsers.filterStatusCode.parse(searchText) {
            var string = AttributedString("Status Code: ") {
                $0.foregroundColor = .primary
            }

            if filter.isNot {
                string.append("NOT ") { $0.foregroundColor = .red }
            }

            if filter.values.isEmpty {
                string.append("200, 400-404") { $0.foregroundColor = .secondary }
            } else {
                for (index, value) in filter.values.enumerated() {
                    string.append(value.title) { $0.foregroundColor = .blue }
                    if index < filter.values.endIndex - 1 {
                        string.append(", ") { $0.foregroundColor = .secondary }
                    }
                }
            }

            suggestions.append(.init(text: string) {
                if filter.values.isEmpty {
                    self.searchBar.text = "Status Code: "
                } else {
                    self.searchBar.text = ""
                    self.searchBar.tokens.append(.filter(.statusCode(filter)))
                }
            })
        }

        // Host
        if let filter = try? Parsers.filterHost.parse(searchText) {
            var string = AttributedString("Host: ") {
                $0.foregroundColor = .primary
            }
            if filter.isNot {
                string.append("NOT ") { $0.foregroundColor = .red }
            }
            if filter.values.isEmpty {
                string.append("example.com") { $0.foregroundColor = .secondary }
            } else {
                for (index, value) in filter.values.enumerated() {
                    string.append(value) { $0.foregroundColor = .blue }
                    if index < filter.values.endIndex - 1 {
                        string.append(", ") { $0.foregroundColor = .secondary }
                    }
                }
            }
            suggestions.append(.init(text: string) {
                if filter.values.isEmpty {
                    self.searchBar.text = "Host: "
                } else {
                    self.searchBar.text = ""
                    self.searchBar.tokens.append(.filter(.host(filter)))
                }
            })
        }

        for scope in ConsoleSearchScope.allCases {
            if (try? Parsers.filterName(scope.title).parse(searchText)) != nil {
                var string = AttributedString("Search in ")
                string.foregroundColor = .primary
                string.append(scope.title) {
                    $0.foregroundColor = .blue
                }
                suggestions.append(.init(text: string) {
                    self.searchBar.text = ""
                    self.searchBar.tokens.append(.scope(scope))
                })
            }
        }

        self.suggestedTokens = suggestions
    }

    func buttonShowMoreResultsTapped() {
        isSearching = true
        operation?.resume()
    }

    // MARK: ConsoleSearchOperationDelegate

    func searchOperation(_ operation: ConsoleSearchOperation, didAddResults results: [ConsoleSearchResultViewModel]) {
        guard self.operation === operation else { return }

        if let dirtyDate = dirtyDate {
            self.buffer += results
            if Date().timeIntervalSince(dirtyDate) > 0.2 {
                self.dirtyDate = nil
                self.results = buffer
                self.buffer = []
            }
        } else {
            self.results += results
        }
    }

    func searchOperationDidFinish(_ operation: ConsoleSearchOperation, hasMore: Bool) {
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
struct ConsoleSearchSuggestion: Identifiable {
    let id = UUID()
    let text: AttributedString
    var onTap: () -> Void
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchResultViewModel: Identifiable {
    var id: NSManagedObjectID { entity.objectID }
    let entity: NSManagedObject
    let occurences: [ConsoleSearchOccurence]
}
