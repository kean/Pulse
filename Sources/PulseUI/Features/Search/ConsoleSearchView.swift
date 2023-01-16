// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#warning("improve how search status is displayed")
#warning("improve search status & remove hardcoded occurenes")

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    var body: some View {
        List {
            if viewModel.searchBar.isEmpty, !viewModel.recentSearches.isEmpty {
                ConsoleSearchRecentSearchesView(viewModel: viewModel)
            }

            ConsoleSearchSuggestedTokensView(viewModel: viewModel)

            if viewModel.isSearching || !viewModel.results.isEmpty {
                ZStack(alignment: .center) {
                    Text("\(viewModel.results.count) results with \(21) occurences")
                        .foregroundColor(.secondary)
                        .font(ConsoleConstants.fontBody)
                        .frame(maxWidth: .infinity, alignment: .center)
                    if viewModel.isSpinnerNeeded {
                        ProgressView()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
            }
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
                viewModel.searchBar.text = "Nuke"
                return viewModel
            }())
        }
#if os(watchOS)
        .navigationViewStyle(.stack)
#endif
    }
}
#endif
