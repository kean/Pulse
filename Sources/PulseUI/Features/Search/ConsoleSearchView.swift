// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#warning("improve how search status is displayed")
#warning("improve search status & remove hardcoded occurenes")
#warning("use return key to apply filter instead of performing search (?) what about recent searches then?")
#warning("when typning, display only a few top suggested filters")
#warning("when user is entering more messages, automatically refresh search results")
#warning("possible to switch to List or make sure the content update without jumping using any other approach?")
#warning("fix an issue where occurence twice in the same line (see imageKit in request body as example)")
#warning("show palceholer when results are empty")


#warning("create ConsoleSearchViewModel here as configure with ConsoleViewModel")

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
            Text("In progress")
        }
        if viewModel.searchBar.isEmpty, !viewModel.recentSearches.isEmpty {
            ConsoleSearchRecentSearchesView(viewModel: viewModel)
        }
        ConsoleSearchSuggestedTokensView(viewModel: viewModel)

        if viewModel.searchBar.text.count > 1 {
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

    private var toolbar: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(viewModel.toolbarTitle)
                .foregroundColor(.secondary)
            Spacer()
            ConsoleFiltersView(viewModel: consoleViewModel)
                .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
        .padding(.top, -14)
    }
}
