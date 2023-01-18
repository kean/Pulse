// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchRecentSearchesView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    #warning("render tokens")
    var body: some View {
        Section(header: header) {
            ForEach(viewModel.recentSearches.prefix(3), id: \.self) { search in
                Button(action: { viewModel.selectRecentSearch(search) }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text(search.searchTerms.joined(separator: ", "))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Recent Searches")
            Spacer()
            Button(action: viewModel.clearRecentSearchess) {
                Text("Clear")
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
        }
    }
}
