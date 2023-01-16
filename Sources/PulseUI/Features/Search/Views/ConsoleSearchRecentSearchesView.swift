// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

#warning("improve how recent search are saved and when")

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchRecentSearchesView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    var body: some View {
        Section(header: header) {
            ForEach(viewModel.recentSearches, id: \.self) { search in
                Button(action: { viewModel.selectRecentSearch(search) }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .font(ConsoleConstants.fontBody)
                        Text(search.searchTerm)
                            .foregroundColor(.primary)
                            .font(ConsoleConstants.fontBody)
                    }
                }.buttonStyle(.plain)
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
            }.buttonStyle(.plain)
        }
    }
}
