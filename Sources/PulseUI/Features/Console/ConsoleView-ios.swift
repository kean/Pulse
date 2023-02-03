// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel // Never reloads

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }


    public var body: some View {
        ConsoleListView(viewModel: viewModel)
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
            .navigationTitle(viewModel.title)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    leadingNavigationBarItems
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    trailingNavigationBarItems
                }
            }
            .background(ConsoleRouterView(viewModel: viewModel))
    }

    private var leadingNavigationBarItems: some View {
        viewModel.onDismiss.map {
            Button(action: $0) { Text("Close") }
        }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        switch viewModel.source {
        case .store:
            ConsoleShareButton(viewModel: viewModel)
            Button(action: { viewModel.router.isShowingFilters = true }) {
                Image(systemName: "line.horizontal.3.decrease.circle")
            }
            ConsoleContextMenu(viewModel: viewModel)
        case .entities:
            ConsoleShareButton(viewModel: viewModel)
        }
    }
}

private struct ConsoleListView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject private var searchBarViewModel: ConsoleSearchBarViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.searchBarViewModel = viewModel.searchBarViewModel
    }

    var body: some View {
        let list = List {
            if #available(iOS 15, *) {
                _ConsoleSearchableContentView(viewModel: viewModel)
            } else {
                _ConsoleRegularContentView(viewModel: viewModel)
            }
        }
            .listStyle(.plain)
        if #available(iOS 16, *) {
            list
                .environment(\.defaultMinListRowHeight, 8)
                .searchable(text: $searchBarViewModel.text, tokens: $searchBarViewModel.tokens, token: {
                    if let image = $0.systemImage {
                        Label($0.title, systemImage: image)
                    } else {
                        Text($0.title)
                    }
                })
                .onSubmit(of: .search, viewModel.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        } else if #available(iOS 15, *) {
            list
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search, viewModel.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        } else {
            list
        }
    }
}

@available(iOS 15, *)
private struct _ConsoleSearchableContentView: View {
    let viewModel: ConsoleViewModel
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        contents.onChange(of: isSearching) {
            viewModel.isSearching = $0
        }
    }

    @ViewBuilder
    private var contents: some View {
        if isSearching {
            ConsoleSearchView(viewModel: viewModel)
        } else {
            _ConsoleRegularContentView(viewModel: viewModel)
        }
    }
}

private struct _ConsoleRegularContentView: View {
    let viewModel: ConsoleViewModel

    var body: some View {
        let toolbar = ConsoleToolbarView(viewModel: viewModel)
        if #available(iOS 15.0, *) {
            toolbar.listRowSeparator(.hidden, edges: .top)
        } else {
            toolbar
        }
        ConsoleListContentView(viewModel: viewModel.list)
    }
}

// MARK: - Previews

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleView(viewModel: .init(store: .mock))
            }.previewDisplayName("Console")
            NavigationView {
                ConsoleView.network(store: .mock)
            }.previewDisplayName("Network")
        }
    }
}
#endif

#endif

extension ConsoleView {
    /// Creates a view pre-configured to display only network requests
    public static func network(store: LoggerStore = .shared) -> ConsoleView {
        ConsoleView(viewModel: .init(store: store, isOnlyNetwork: true))
    }
}
