// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 15, macOS 13, *)
struct ConsoleListView: View {
    @EnvironmentObject var environment: ConsoleEnvironment
    @EnvironmentObject var filters: ConsoleFiltersViewModel

    var body: some View {
        _InternalConsoleListView(environment: environment, filters: filters)
    }
}

@available(iOS 15, macOS 13, *)
private struct _InternalConsoleListView: View {
    private let environment: ConsoleEnvironment

    @StateObject private var listViewModel: IgnoringUpdates<ConsoleListViewModel>
    @StateObject private var searchBarViewModel: ConsoleSearchBarViewModel
    @StateObject private var searchViewModel: IgnoringUpdates<ConsoleSearchViewModel>

    init(environment: ConsoleEnvironment, filters: ConsoleFiltersViewModel) {
        self.environment = environment

        let listViewModel = ConsoleListViewModel(environment: environment, filters: filters)
        let searchBarViewModel = ConsoleSearchBarViewModel()
        let searchViewModel = ConsoleSearchViewModel(environment: environment, source: listViewModel, searchBar: searchBarViewModel)

        _listViewModel = StateObject(wrappedValue: IgnoringUpdates(listViewModel))
        _searchBarViewModel = StateObject(wrappedValue: searchBarViewModel)
        _searchViewModel = StateObject(wrappedValue: IgnoringUpdates(searchViewModel))
    }

    var body: some View {
        contents
            .environmentObject(listViewModel.value)
            .environmentObject(searchViewModel.value)
            .environmentObject(searchBarViewModel)
            .onAppear { listViewModel.value.isViewVisible = true }
            .onDisappear { listViewModel.value.isViewVisible = false }
    }

    @ViewBuilder private var contents: some View {
        if #available(iOS 16, *) {
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
@available(iOS 15, *)
private struct _ConsoleListView: View {
    @Environment(\.isSearching) private var isSearching
    @Environment(\.store) private var store

    @ObservedObject private var syncSession = WatchConnectivityService.shared
    @State private var presentedStore: LoggerStore?

    var body: some View {
        List {
            if isSearching {
                ConsoleSearchListContentView()
            } else {
                ConsoleToolbarView()
                    .listRowSeparator(.hidden, edges: .top)
                if store === LoggerStore.shared, let storeURL = syncSession.importedStoreURL {
                    buttonShowImportedStore(storeURL: storeURL)
                }
                ConsoleListContentView()
            }
        }
        .listStyle(.plain)
        .sheet(item: $presentedStore) { store in
            NavigationView {
                ConsoleView(store: store)
            }
        }
    }

    private func buttonShowImportedStore(storeURL: URL) -> some View {
        HStack {
            Button(action: {
                presentedStore = try? LoggerStore(storeURL: storeURL, options: [.readonly])
            }) {
                HStack {
                    Text(Image(systemName: "applewatch"))
                    Text("Show Imported Store")
                }.foregroundColor(.blue)
            }.buttonStyle(.plain)
            Spacer()
            Button(role: .destructive, action: syncSession.removeImportedDocument) {
                Image(systemName: "trash")
            }
        }
    }
}
#endif

#if os(macOS)
@available(iOS 15, macOS 13, *)
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
                        ConsoleListContentView(proxy: proxy)
                    }
                }
            }
            .environment(\.defaultMinListRowHeight, 1)
        }
    }
}
#endif
