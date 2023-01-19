// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#warning("fix an issue where pending task state is not getting updated")

#warning("improve how search status is displayed")
#warning("improve search status & remove hardcoded occurenes")
#warning("use return key to apply filter instead of performing search (?) what about recent searches then?")
#warning("when typning, display only a few top suggested filters")
#warning("when user is entering more messages, automatically refresh search results")
#warning("possible to switch to List or make sure the content update without jumping using any other approach?")
#warning("fix an issue where occurence twice in the same line (see imageKit in request body as example)")
#warning("show palceholer when results are empty")


#warning("create ConsoleSearchViewModel here as configure with ConsoleViewModel")

#warning("try and fix searchable animation issue")
#warning("display spinner in new toolbar")

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
        Section(header: toolbar) {
            makeList(with: viewModel.topSuggestions)
        }

        if !viewModel.suggestedScopes.isEmpty {
            Section(header: Text("Suggested Scopes")) {
                makeList(with: viewModel.suggestedScopes)
            }
        }

        if viewModel.searchBar.isEmpty, !viewModel.recentSearches.isEmpty {
            ConsoleSearchRecentSearchesView(viewModel: viewModel)
        }

        if viewModel.isNewResultsButtonShown {
            Section {
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
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .padding(.vertical, -8)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            }
        }

        if !viewModel.searchBar.parameters.searchTerms.isEmpty {
            ForEach(viewModel.results) { result in
                Section {
                    ConsoleSearchResultView(viewModel: result)
                }
            }
        } else {
            Section {
                ForEach(viewModel.results) { result in
                    ConsoleSearchResultView(viewModel: result)
                }
            }
        }
        if !viewModel.isSearching && viewModel.hasMore {
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
        ConsoleToolbarView(title: viewModel.toolbarTitle, isSpinnerNeeded: viewModel.isSpinnerNeeded, viewModel: consoleViewModel)
    }
}

#endif
