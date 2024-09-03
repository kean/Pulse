// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 15, visionOS 1.0, *)
struct ConsoleListView: View {
    @EnvironmentObject var environment: ConsoleEnvironment
    @EnvironmentObject var filters: ConsoleFiltersViewModel

    var body: some View {
        _InternalConsoleListView(environment: environment, filters: filters)
    }
}

@available(iOS 15, visionOS 1.0, *)
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
        _ConsoleListView()
#if os(macOS)
            .searchable(text: $searchBarViewModel.text, placement: .sidebar)
#else
            .environment(\.defaultMinListRowHeight, 8)
            .searchable(text: $searchBarViewModel.text)
            .textInputAutocapitalization(.never)
#endif
            .onSubmit(of: .search, searchViewModel.value.onSubmitSearch)
            .disableAutocorrection(true)
    }
}

#endif

#if os(iOS) || os(visionOS)
@available(iOS 15, visionOS 1.0, *)
private struct _ConsoleListView: View {
    @Environment(\.isSearching) private var isSearching
    @Environment(\.store) private var store

    var body: some View {
        List {
            if isSearching {
                ConsoleSearchListContentView()
            } else {
                ConsoleToolbarView()
                    .listRowSeparator(.hidden, edges: .top)
                ConsoleListContentView()
            }
        }
        .listStyle(.plain)
    }
}
#endif
