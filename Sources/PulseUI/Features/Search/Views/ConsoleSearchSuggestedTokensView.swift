// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestedTokensView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    #warning("how do we decide what filters/scopes to suggest? use confidence for both?")

    var body: some View {
        if viewModel.searchBar.isEmpty {
            if !viewModel.suggestedFilters.isEmpty {
                Section(header: Text("Suggested Filters")) {
                    ForEach(viewModel.suggestedFilters) {
                        ConsoleSearchSuggestionView(suggestion: $0, isActionable: viewModel.isActionable($0))
                    }
                }
            }
            if !viewModel.suggestedScopes.isEmpty {
                Section(header: Text("Suggested Scopes")) {
                    ForEach(viewModel.suggestedScopes) {
                        ConsoleSearchSuggestionView(suggestion: $0, isActionable: viewModel.isActionable($0))
                    }
                }
            }
        } else {
            // Show suggestions in a single group with no header to save verical space
            if !viewModel.suggestedFilters.isEmpty || !viewModel.suggestedScopes.isEmpty {
                Section {
                    ForEach((viewModel.suggestedFilters + viewModel.suggestedScopes).prefix(3)) {
                        ConsoleSearchSuggestionView(suggestion: $0, isActionable: viewModel.isActionable($0))
                    }
                }
            }
        }
    }
}

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchSuggestionView: View {
    let suggestion: ConsoleSearchSuggestion
    var isActionable = false

    var body: some View {
        Button(action: suggestion.onTap) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text(suggestion.text)
                if isActionable {
                    Spacer()
                    Image(systemName: "return")
                }
            }
        }
    }
}
