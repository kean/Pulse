// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(iOS)

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel
    let consoleViewModel: ConsoleViewModel

    init(viewModel: ConsoleViewModel) {
        self.consoleViewModel = viewModel
        self.viewModel = viewModel.searchViewModel
    }

    var body: some View {
        suggestionsView
        if viewModel.isNewResultsButtonShown {
            showNewResultsPromptView
        }
        searchResultsView
    }

    @ViewBuilder
    private var suggestionsView: some View {
        toolbar
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden, edges: .top)
        let suggestions = viewModel.suggestionsViewModel!
        if !suggestions.searches.isEmpty {
            makeList(with: suggestions.searches)
            buttonClearSearchHistory
        } else {
            makeList(with: suggestions.filters)
        }

        if !suggestions.searches.isEmpty && !suggestions.filters.isEmpty {
            // Display filters in a separate section
            PlainListSectionHeaderSeparator(title: "Filters")
            makeList(with: suggestions.filters)
        }

        if !suggestions.scopes.isEmpty {
            PlainListSectionHeaderSeparator(title: "Scopes").padding(.top, 16)
            makeList(with: suggestions.scopes)
        }
    }

    private var buttonClearSearchHistory: some View {
        HStack {
            Spacer()
            Button(action: viewModel.buttonClearRecentSearchesTapped) {
                HStack {
                    Text("Clear Search History")
                }
                .foregroundColor(.blue)
                .font(.subheadline)
            }.buttonStyle(.plain)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden, edges: .bottom)
    }

    @ViewBuilder
    private var showNewResultsPromptView: some View {
        Button(action: viewModel.buttonShowNewlyAddedSearchResultsTapped) {
            HStack {
                Text("New Results Available")
                Image(systemName: "arrow.clockwise.circle.fill")
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(8)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.separator.opacity(0.2))
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var searchResultsView: some View {
        if !viewModel.results.isEmpty {
            PlainListGroupSeparator()
        }
        ForEach(viewModel.results) { result in
            let isLast = result.id === viewModel.results.last?.id
            ConsoleSearchResultView(viewModel: result, isSeparatorNeeded: !viewModel.parameters.terms.isEmpty && !isLast)
        }
        if !viewModel.isSearching && viewModel.hasMore {
            PlainListGroupSeparator()
            Button(action: viewModel.buttonShowMoreResultsTapped) {
                Text("Show More Results")
            }
        }
    }

    private func makeList(with suggestions: [ConsoleSearchSuggestion]) -> some View {
        ForEach(suggestions) { suggestion in
            ConsoleSearchSuggestionView(
                suggestion: suggestion,
                isActionable: viewModel.isActionable(suggestion),
                action: { viewModel.perform(suggestion) }
            )
        }
    }

    private var toolbar: some View {
        ConsoleSearchToolbar(title: viewModel.toolbarTitle, isSpinnerNeeded: viewModel.isSpinnerNeeded, viewModel: consoleViewModel)
    }

    @ViewBuilder
    private var footer: some View {
        if viewModel.parameters.isEmpty, viewModel.hasRecentSearches {
            HStack {
                Spacer()
                Button(action: viewModel.buttonClearRecentSearchesTapped) {
                    Text("Clear History").font(.callout)
                }.foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}

#endif
