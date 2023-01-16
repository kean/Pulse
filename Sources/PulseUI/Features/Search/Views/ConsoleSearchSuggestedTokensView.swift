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

    var body: some View {
        if !viewModel.suggestedFilters.isEmpty {
            Section(header: Text("Suggested Filters")) {
                ForEach(viewModel.suggestedFilters, content: ConsoleSearchSuggestionView.init)
            }
        }
        if !viewModel.suggestedFilters.isEmpty {
            Section(header: Text("Suggested Scopes")) {
                ForEach(viewModel.suggestedScopes, content: ConsoleSearchSuggestionView.init)
            }
        }
    }
}

@available(iOS 15, tvOS 15, *)
private struct ConsoleSearchSuggestionView: View {
    let suggestion: ConsoleSearchSuggestion

    var body: some View {
        Button(action: suggestion.onTap) {
            HStack {
                Image(systemName: "magnifyingglass")
                Text(suggestion.text)
            }
        }
    }
}
