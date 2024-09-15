// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 16, visionOS 1, *)
struct ConsoleSearchListContentView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
        ConsoleSearchToolbar()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden, edges: .top)
        ConsoleSearchSuggestionsView()
        if viewModel.isNewResultsButtonShown {
            showNewResultsPromptView
        }
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
            .background(Color.accentColor)
            .cornerRadius(8)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.separator.opacity(0.2))
        .frame(maxWidth: .infinity, alignment: .center)
        .listRowBackground(Color.clear)
    }
}

@available(iOS 16, visionOS 1, *)
struct ConsoleSearchResultsListContentView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    var body: some View {
        if !viewModel.results.isEmpty {
            PlainListGroupSeparator()
        }
        ForEach(viewModel.results) { result in
            let isLast = result.id == viewModel.results.last?.id
            ConsoleSearchResultView(viewModel: result, isSeparatorNeeded: viewModel.parameters.term != nil && !isLast)
                .onAppear {
                    viewModel.didScroll(to: result)
                }
        }
        if !viewModel.isSearching && !viewModel.hasMore && !viewModel.results.isEmpty {
            Text("No more results")
                .frame(maxWidth: .infinity, minHeight: 24, alignment: .center)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden, edges: .bottom)
        }
    }
}

#endif
