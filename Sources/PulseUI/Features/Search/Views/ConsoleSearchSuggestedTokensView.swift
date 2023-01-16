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
    }
}

@available(iOS 15, tvOS 15, *)
private struct ConsoleSearchSuggestionView: View {
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
