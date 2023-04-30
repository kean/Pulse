// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, macOS 13, *)
struct ConsoleSearchListContentView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
#if os(iOS)
        ConsoleSearchToolbar()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden, edges: .top)
        ConsoleSearchSuggestionsView()
        if viewModel.isNewResultsButtonShown {
            showNewResultsPromptView
        }
#endif
        ConsoleSearchResultsListContentView()
    }

    @ViewBuilder private var showNewResultsPromptView: some View {
        Button(action: viewModel.buttonShowNewlyAddedSearchResultsTapped) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill")
                Text("New Results Added")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(8)
            .background(Color.blue)
            .cornerRadius(8)
        }
#if os(iOS)
        .listRowSeparator(.hidden)
#endif
        .listRowBackground(Color.separator.opacity(0.2))
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }
}

@available(iOS 15, macOS 13, *)
struct ConsoleSearchResultsListContentView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
#if os(iOS)
        if !viewModel.results.isEmpty {
            PlainListGroupSeparator()
        }
#endif
        ForEach(viewModel.results) { result in
            let isLast = result.id == viewModel.results.last?.id
            ConsoleSearchResultView(viewModel: result, isSeparatorNeeded: !viewModel.parameters.terms.isEmpty && !isLast)
        }
        if !viewModel.isSearching && viewModel.hasMore {
#if os(iOS)
            PlainListGroupSeparator()
#endif
            Button(action: viewModel.buttonShowMoreResultsTapped) {
                Text("Show More Results")
            }
        }
    }
}

#endif
