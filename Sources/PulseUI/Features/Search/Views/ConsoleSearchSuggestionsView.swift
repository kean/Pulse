// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 16, visionOS 1, *)
struct ConsoleSearchSuggestionsView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
        let suggestions = viewModel.suggestionsViewModel!
        if !suggestions.searches.isEmpty {
            makeList(with: Array(suggestions.searches.prefix(3)))
            buttonClearSearchHistory
        }

        if viewModel.parameters.isEmpty {
            ConsoleSearchScopesPicker(viewModel: viewModel)
        }
    }

    private var buttonClearSearchHistory: some View {
        HStack {
            Spacer()
            Button(action: viewModel.buttonClearRecentSearchesTapped) {
                HStack {
                    Text("Clear Search History")
                }
                .foregroundColor(.accentColor)
                .font(.subheadline)
            }.buttonStyle(.plain)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden, edges: .bottom)
    }

    private func makeList(with suggestions: [ConsoleSearchSuggestion]) -> some View {
        ForEach(suggestions) { suggestion in
            ConsoleSearchSuggestionView(suggestion: suggestion) {
                viewModel.perform(suggestion)
            }
        }
    }
}

#if DEBUG
@available(iOS 16, visionOS 1, *)
struct Previews_ConsoleSearchSuggestionsView_Previews: PreviewProvider {
    static let environment = ConsoleEnvironment(store: .mock)

    static var previews: some View {
        List {
            ConsoleSearchSuggestionsView()
        }
        .listStyle(.plain)
        .injecting(environment)
        .environmentObject(ConsoleSearchViewModel(environment: environment, source: ConsoleListViewModel(environment: environment, filters: .init(options: .init())), searchBar: .init()))
        .frame(width: 340)
    }
}
#endif

#endif
