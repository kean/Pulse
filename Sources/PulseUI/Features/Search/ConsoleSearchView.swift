// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

// TODO: stop updating when leaving background
// TODO: instead of tokens, use something similar to custom search filters
// TODO: do we need searchabl then?

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    // TODO: implement recent searches (and move this)
    // TODO: add a way to clear them
    struct RecentSearchesView: View {
        var body: some View {
            Section(header: Text("Recent Searches")) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(ConsoleConstants.fontBody)
                    Text("Status Code 200")
                        .foregroundColor(.primary)
                        .font(ConsoleConstants.fontBody)
                }
            }
        }
    }

    var body: some View {
        List {
            if viewModel.results.isEmpty {
                RecentSearchesView()
            }
            ConsoleSearchSuggestedTokensView(viewModel: viewModel)

            if viewModel.searchText.count > 1 {
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
            if viewModel.isSpinnerNeeded {
                ProgressView("Searching…")
                    .listRowBackground(Color.clear)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .id(UUID())
            }
            if !viewModel.isSearching && viewModel.hasMore {
                Button(action: viewModel.buttonShowMoreResultsTapped) {
                    Text("Show More Results")
                }
            }
        }
            .environment(\.defaultMinListRowHeight, 0)
#if os(iOS)
            .listStyle(.insetGrouped)
#endif
    }
}

#if DEBUG
@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleSearchView(viewModel: {
                let viewModel = ConsoleSearchViewModel(entities: try! LoggerStore.mock.allMessages(), store: .mock)
                viewModel.searchText = "Nuke"
                return viewModel
            }())
        }
#if os(watchOS)
        .navigationViewStyle(.stack)
#endif
    }
}
#endif
