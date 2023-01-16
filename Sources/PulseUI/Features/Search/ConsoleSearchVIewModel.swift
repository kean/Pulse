// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
final class ConsoleSearchViewModel: ObservableObject, ConsoleSearchOperationDelegate {
    private var entities: [NSManagedObject]
    private var objectIDs: [NSManagedObjectID]

    @Published private(set) var results: [ConsoleSearchResultViewModel] = []
    @Published var searchText: String = ""
    @Published var isSpinnerNeeded = false
    @Published var isSearching = false
    @Published var hasMore = false

    private var dirtyDate: Date?
    private var buffer: [ConsoleSearchResultViewModel] = []
    private var operation: ConsoleSearchOperation?

    #warning("remove old tokens")
    @Published var tokens: [ConsoleSearchToken] = []
    @Published var suggestedTokens: [ConsoleSearchSuggestion] = []

    private let service = ConsoleSearchService()

    private var cancellables: [AnyCancellable] = []
    private let context: NSManagedObjectContext

    init(entities: [NSManagedObject], store: LoggerStore) {
        self.entities = entities
        self.objectIDs = entities.map(\.objectID)
        self.context = store.newBackgroundContext()

        Publishers.CombineLatest($searchText, $tokens).sink { [weak self] in
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

        guard !searchText.isEmpty else {
            self.suggestedTokens = []
            return
        }

        var suggestions: [ConsoleSearchSuggestion] = []

#warning("more IS NOT options + fix colors")
        // Status Code
        if let code = Int(searchText), (100...500).contains(code) {
            suggestions.append(.init(text: AttributedString("Status Code IS ") { $0.foregroundColor = .secondary } + AttributedString(searchText)) {
                self.searchText = ""
                self.tokens.append(.status(range: code...code, isNot: false))
            })
            suggestions.append(.init(text: AttributedString("Status Code IS NOT ") { $0.foregroundColor = .secondary } + AttributedString(searchText)) {
                self.searchText = ""
                self.tokens.append(.status(range: code...code, isNot: false))
            })
        }
#warning("finish this prototype")
#warning("different styles for filters and completions")
#warning("dont show suggestion when its not specific enough")
#warning("search like in xcode with first letter only")
#warning("make it all case insensitive")
        // Response
        if "Response ".hasPrefix(searchText) {
            do {
                var string = AttributedString("Response")
                string.foregroundColor = .secondary
                string[string.range(of: searchText)!].foregroundColor = .primary

                suggestions.append(.init(text: string) { self.searchText = "Response " })
            }
            do {
                var string = AttributedString("Response Body")
                string.foregroundColor = .secondary
                string[string.range(of: searchText)!].foregroundColor = .primary

                suggestions.append(.init(text: string) { self.searchText = "Response Body " })
            }
            do {
                var string = AttributedString("Response Headers")
                string.foregroundColor = .secondary
                string[string.range(of: searchText)!].foregroundColor = .primary

                suggestions.append(.init(text: string) { self.searchText = "Response Headers " })
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
            if Date().timeIntervalSince(dirtyDate) > 0.1 {
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
