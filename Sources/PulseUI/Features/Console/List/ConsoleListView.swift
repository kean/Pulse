// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct ConsoleListView: View {
    @EnvironmentObject var environment: ConsoleEnvironment
    @EnvironmentObject var filters: ConsoleFiltersViewModel

    var body: some View {
        _InternalConsoleListView(environment: environment, filters: filters)
    }
}

private struct _InternalConsoleListView: View {
    private let environment: ConsoleEnvironment

    @StateObject private var listViewModel: ConsoleListViewModel

    init(environment: ConsoleEnvironment, filters: ConsoleFiltersViewModel) {
        self.environment = environment
        _listViewModel = StateObject(wrappedValue: .init(environment: environment, filters: filters))
    }

    var body: some View {
        contents
            .environmentObject(listViewModel)
            .onAppear { listViewModel.isViewVisible = true }
            .onDisappear { listViewModel.isViewVisible = false }
    }

    @ViewBuilder private var contents: some View {
        if #available(iOS 15, *) {
            _ConsoleNewListView(listViewModel: listViewModel, environment: environment)
        } else {
            _ConsoleListView()
        }
    }
}

@available(iOS 15, *)
private struct _ConsoleNewListView: View {
    let environment: ConsoleEnvironment

    @ObservedObject private var listViewModel: ConsoleListViewModel

    @StateObject private var searchBarViewModel: ConsoleSearchBarViewModel
    @StateObject private var searchViewModel: ObservableBag<ConsoleSearchViewModel>

    init(listViewModel: ConsoleListViewModel, environment: ConsoleEnvironment) {
        self.environment = environment
        self.listViewModel = listViewModel

        let searchBarViewModel = ConsoleSearchBarViewModel()
        let searchViewModel = ConsoleSearchViewModel(environment: environment, list: listViewModel, searchBar: searchBarViewModel)

        _searchBarViewModel = StateObject(wrappedValue: searchBarViewModel)
        _searchViewModel = StateObject(wrappedValue: ObservableBag(searchViewModel))
    }

    var body: some View {
        list
            .environmentObject(searchBarViewModel)
            .environmentObject(searchViewModel.value)
    }

    @ViewBuilder private var list: some View {
        if #available(iOS 16, macOS 13, *) {
            _ConsoleListView()
                .environment(\.defaultMinListRowHeight, 8)
                .searchable(text: $searchBarViewModel.text, tokens: $searchBarViewModel.tokens, token: {
                    if let image = $0.systemImage {
                        Label($0.title, systemImage: image)
                    } else {
                        Text($0.title)
                    }
                })
#if os(macOS)
                .searchSuggestions {
                    ConsoleSearchSuggestionsView()
                }
#endif
                .onSubmit(of: .search, searchViewModel.value.onSubmitSearch)
                .disableAutocorrection(true)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
        } else {
            _ConsoleListView()
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search, searchViewModel.value.onSubmitSearch)
                .disableAutocorrection(true)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
        }
    }
}

#endif

#if os(iOS)
private struct _ConsoleListView: View {
    var body: some View {
        List {
            if #available(iOS 15, *) {
                _ConsoleSearchableListView()
            } else {
                _ConsoleRegularListView()
            }
        }
        .listStyle(.plain)
    }
}

@available(iOS 15, *)
private struct _ConsoleSearchableListView: View {
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        if isSearching {
            ConsoleSearchListContentView()
        } else {
            _ConsoleRegularListView()
        }
    }
}

private struct _ConsoleRegularListView: View {
    @EnvironmentObject private var listViewModel: ConsoleListViewModel

    var body: some View {
        let toolbar = ConsoleToolbarView()
        if #available(iOS 15, macOS 13, *) {
            toolbar.listRowSeparator(.hidden, edges: .top)
        } else {
            toolbar
        }
        ConsoleListContentView(viewModel: listViewModel)
    }
}
#endif

#if os(macOS)

private struct _ConsoleListView: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @EnvironmentObject private var listViewModel: ConsoleListViewModel
    @EnvironmentObject private var searchViewModel: ConsoleSearchViewModel

    @State private var selectedObjectID: NSManagedObjectID? // Has to use for Table
    @State private var selection: ConsoleSelectedItem?
    @State private var shareItems: ShareItems?

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        content
            .onChange(of: selectedObjectID) {
                environment.router.selection = $0.map(ConsoleSelectedItem.entity)
            }
            .onChange(of: selection) {
                environment.router.selection = $0
            }
            .onChange(of: isSearching) {
                searchViewModel.isSearchActive = $0
            }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            if isSearching && !searchViewModel.parameters.isEmpty {
                ConsoleSearchToolbar()
            } else {
                ConsoleToolbarView()
            }
            Divider()
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    if isSearching && !searchViewModel.parameters.isEmpty {
                        ConsoleSearchResultsListContentView()
                    } else {
                        ConsoleListContentView(viewModel: listViewModel, proxy: proxy)
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 1)
            .apply(addListContextMenu)
        }
    }

    @ViewBuilder
    private func addListContextMenu<T: View>(_ view: T) -> some View {
        if #available(macOS 13, *) {
            view.contextMenu(forSelectionType: ConsoleSelectedItem.self, menu: { _ in }) {
                $0.first.map(makeDetailsView)?.showInWindow()
            }
        } else {
            view
        }
    }

    @ViewBuilder
    private func makeDetailsView(for item: ConsoleSelectedItem) -> some View {
        switch item {
        case .entity(let objectID):
            if let entity = try? environment.store.viewContext.existingObject(with: objectID) {
                ConsoleEntityStandaloneDetailsView(entity: entity)
                    .frame(minWidth: 400, idealWidth: 700, minHeight: 400, idealHeight: 480)
            }
        case .occurrence(let objectID, let occurrence):
            if let entity = try? environment.store.viewContext.existingObject(with: objectID) {
                ConsoleSearchResultView.makeDestination(for: occurrence, entity: entity)
                    .frame(minWidth: 400, idealWidth: 700, minHeight: 400, idealHeight: 480)
            }
        }
    }
}
#endif
