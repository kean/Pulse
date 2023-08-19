// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, *)
struct ConsoleSearchSuggestionsView: View {
    @EnvironmentObject private var viewModel: ConsoleSearchViewModel

    @State private var isShowingScopePicker = false

    var body: some View {
#if os(macOS)
        if viewModel.parameters.isEmpty {
            HStack {
                ConsoleSearchStringOptionsView(viewModel: viewModel)
                Spacer()
                ConsoleSearchPickScopesButton {
                    isShowingScopePicker.toggle()
                }
            }
        }
        if isShowingScopePicker {
                PlainListSectionHeaderSeparator(title: "Scopes").padding(.top, 16)
            VStack {
                ConsoleSearchScopesPicker(viewModel: viewModel)
            }
        }
#endif

        let suggestions = viewModel.suggestionsViewModel!
        if !suggestions.searches.isEmpty {
#if os(macOS)
            PlainListSectionHeaderSeparator(title: "Recent Searches").padding(.top, 16)
#endif
            makeList(with: Array(suggestions.searches.prefix(3)))
            buttonClearSearchHistory
        } else {
            makeList(with: suggestions.filters)
        }

        if !suggestions.searches.isEmpty && !suggestions.filters.isEmpty {
            // Display filters in a separate section
            PlainListSectionHeaderSeparator(title: "Filters")
            makeList(with: suggestions.filters)
        }

#if os(iOS)
        if viewModel.parameters.isEmpty {
            PlainListSectionHeaderSeparator(title: "Scopes").padding(.top, 16)
            ConsoleSearchScopesPicker(viewModel: viewModel)
        }
#endif
    }

    private var buttonClearSearchHistory: some View {
        HStack {
            Spacer()
            Button(action: viewModel.buttonClearRecentSearchesTapped) {
                HStack {
                    Text("Clear Search History")
                }
                .foregroundColor(.accentColor)
                .font(.subheadline)
            }.buttonStyle(.plain)
        }
#if os(iOS)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 20))
        .listRowSeparator(.hidden, edges: .bottom)
#endif
    }

    private func makeList(with suggestions: [ConsoleSearchSuggestion]) -> some View {
        ForEach(suggestions) { suggestion in
            ConsoleSearchSuggestionView(suggestion: suggestion) {
                viewModel.perform(suggestion)
            }
#if os(macOS)
            .searchCompletion(suggestion.id.uuidString)
#endif
        }
    }
}

#if DEBUG
@available(iOS 15, *)
struct Previews_ConsoleSearchSuggestionsView_Previews: PreviewProvider {
    static let environment = ConsoleEnvironment(store: .mock)

    static var previews: some View {
        List {
            ConsoleSearchSuggestionsView()
        }
        .listStyle(.plain)
        .injecting(environment)
        .environmentObject(ConsoleSearchViewModel(environment: environment, source: ConsoleListViewModel(environment: environment, filters: .init(options: .init())), searchBar: .init()))
        .frame(width: 340)
    }
}
#endif

#endif
