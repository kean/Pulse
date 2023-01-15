// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#warning("TODO: remove public")
public struct _SearchView: View {
    public init() {}

    public var body: some View {
        if #available(iOS 15, *) {
            ConsoleSearchView(viewModel: .init(entities: try! LoggerStore.mock.allMessages(), store: .mock))
        }
    }
}

// TODO: stop updating when leaving background
// TODO: instead of tokens, use something similar to custom search filters
// TODO: do we need searchabl then?

@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel

    // TODO: implement recent searches (and move this)
    // TODO: add a way to clear them
    struct RecentSearchesView: View {
        @Environment(\.isSearching) private var isSearching // important: scope

        var body: some View {
            if !isSearching {
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
    }

    var body: some View {
        let list = List {
            RecentSearchesView()
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
            .listStyle(.insetGrouped)

        if #available(iOS 16, tvOS 16, *) {
            list
                .searchable(text: $viewModel.searchText, tokens: $viewModel.tokens, token: { Text($0.title) })
                .disableAutocorrection(true)
        }  else {
            list.searchable(text: $viewModel.searchText)
                .disableAutocorrection(true)
        }
    }
}

@available(iOS 15, tvOS 15, *)
private struct ConsoleSearchResultView: View {
    let viewModel: ConsoleSearchResultViewModel
    var limit: Int = 4

    var body: some View {
        ConsoleEntityCell(entity: viewModel.entity)
        // TODO: limit number of occurences of the same type (or only have one and display how many more?)
        // TODO: when open body, start with a search term immediatelly
        let occurences = Array(viewModel.occurences.enumerated())
        ForEach(occurences.prefix(limit), id: \.offset) { item in
            NavigationLink(destination: makeDestination(for: item.element, entity: viewModel.entity)) {
                makeCell(for: item.element)
            }
        }
        if occurences.count > limit {
            // TODO: how to prioritize what makes the cut?
            // TODO: implement show-all-occurences
            NavigationLink(destination: ConsoleSearchResultDetailsView(viewModel: viewModel)) {
                HStack {
                    Text("Show All Occurences")
                        .font(ConsoleConstants.fontBody)
                        .foregroundColor(.secondary)
                    Text("\(occurences.count)")
                        .font(ConsoleConstants.fontBody)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // TODO: add occurence IDs instead of indices
    private func makeCell(for occurence: ConsoleSearchOccurence) -> some View {
        return VStack(alignment: .leading, spacing: 4) {
            Text(occurence.kind.title + " (\(occurence.line):\(occurence.range.lowerBound))")
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
            Text(occurence.text)
                .lineLimit(3)
        }
    }

    func makeDestination(for occurence: ConsoleSearchOccurence, entity: NSManagedObject) -> some View {
        switch occurence.kind {
        case .responseBody:
            return NetworkInspectorResponseBodyView(viewModel: .init(task: entity as! NetworkTaskEntity))
                .environment(\.textViewSearchContext, occurence.searchContext)
        }
    }
}

@available(iOS 15, tvOS 15, *)
private struct ConsoleSearchResultDetailsView: View {
    let viewModel: ConsoleSearchResultViewModel

    var body: some View {
        List {
            ConsoleSearchResultView(viewModel: viewModel, limit: Int.max)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .inlineNavigationTitle("Search Results")
    }
}

@available(iOS 15, tvOS 15, *)
private struct ConsoleSearchSuggestedTokensView: View {
    @ObservedObject var viewModel: ConsoleSearchViewModel
    @Environment(\.isSearching) private var isSearching // important: scope

    // TODO: render values for suggestions using attributed strings
    var body: some View {
        if isSearching && !viewModel.suggestedTokens.isEmpty {
            Section(header: Text("Suggested Filters")) {
                ForEach(viewModel.suggestedTokens) { token in
                    Button(action: {
                        viewModel.tokens.append(token)
                        viewModel.searchText = ""
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(ConsoleConstants.fontBody)
                            Text(token.title)
                                .foregroundColor(.primary)
                                .font(ConsoleConstants.fontBody)
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
@available(iOS 15, tvOS 15, *)
struct ConsoleSearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleSearchView(viewModel: .init(entities: try! LoggerStore.mock.allMessages(), store: .mock))
        }
    }
}
#endif
