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
        toolbar
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden, edges: .top)
        makeList(with: viewModel.topSuggestions)
        if viewModel.hasRecentTokens && viewModel.parameters.isEmpty {
            Button(action: viewModel.buttonClearRecentTokensTapped) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Clear Search History")
                }.foregroundColor(.blue)
            }
        }

        if !viewModel.suggestedScopes.isEmpty {
            PlainListSectionHeaderSeparator(title: "Scopes")
                .padding(.top, 16)
            makeList(with: viewModel.suggestedScopes)
        }

        if viewModel.isNewResultsButtonShown {
            Button(action: viewModel.buttonShowNewlyAddedSearchResultsTapped) {
                HStack {
                    Text("New Results Available")
                    Image(systemName: "arrow.clockwise.circle.fill")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.blue)
                .cornerRadius(8)
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.separator.opacity(0.2))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)

        }

        if !viewModel.results.isEmpty {
            PlainListGroupSeparator()
            PlainListGroupSeparator()
        }
        ForEach(viewModel.results) { result in
            ConsoleSearchResultView(viewModel: result, isSeparatorNeeded: !viewModel.parameters.terms.isEmpty)
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
        if viewModel.parameters.isEmpty, viewModel.hasRecentTokens {
            HStack {
                Spacer()
                Button(action: viewModel.buttonClearRecentTokensTapped) {
                    Text("Clear History").font(.callout)
                }.foregroundColor(.secondary.opacity(0.8))
            }
        }
    }
}

#endif
