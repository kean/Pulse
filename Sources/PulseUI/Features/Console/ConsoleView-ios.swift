// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment // Never reloads
    @Environment(\.presentationMode) private var presentationMode
    private var isCloseButtonHidden = false

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
    }

    public var body: some View {
        ConsoleListView(environment: environment)
            .onAppear  { environment.listViewModel.isViewVisible = true }
            .onDisappear { environment.listViewModel.isViewVisible = false }
            .navigationTitle(environment.title)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if !isCloseButtonHidden && presentationMode.wrappedValue.isPresented {
                        Button("Close") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    trailingNavigationBarItems
                }
            }
            .injecting(environment)
    }

    /// Changes the default close button visibility.
    public func closeButtonHidden(_ isHidden: Bool = true) -> ConsoleView {
        var copy = self
        copy.isCloseButtonHidden = isHidden
        return copy
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        Button(action: { environment.router.isShowingShareStore = true }) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        Button(action: { environment.router.isShowingFilters = true }) {
            Image(systemName: "line.horizontal.3.decrease.circle")
        }
        ConsoleContextMenu()
    }
}

private struct ConsoleListView: View {
    let environment: ConsoleEnvironment
    @ObservedObject private var searchBarViewModel: ConsoleSearchBarViewModel

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.searchBarViewModel = environment.searchBarViewModel
    }

    var body: some View {
        let list = List {
            if #available(iOS 15, *) {
                _ConsoleSearchableContentView(environment: environment)
            } else {
                _ConsoleRegularContentView(environment: environment)
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
                .onSubmit(of: .search, environment.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        } else if #available(iOS 15, *) {
            list
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search, environment.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
        } else {
            list
        }
    }
}

@available(iOS 15, *)
private struct _ConsoleSearchableContentView: View {
    let environment: ConsoleEnvironment
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        if isSearching {
            ConsoleSearchView(viewModel: environment.searchViewModel)
                .onAppear {
                    environment.searchViewModel.isViewVisible = true
                }
                .onDisappear {
                    environment.searchViewModel.isViewVisible = false
                }
        } else {
            _ConsoleRegularContentView(environment: environment)
        }
    }
}

private struct _ConsoleRegularContentView: View {
    let environment: ConsoleEnvironment

    var body: some View {
        let toolbar = ConsoleToolbarView()
        if #available(iOS 15.0, *) {
            toolbar.listRowSeparator(.hidden, edges: .top)
        } else {
            toolbar
        }
        ConsoleListContentView(viewModel: environment.listViewModel)
    }
}

// MARK: - Previews

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleView(environment: .init(store: .mock))
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
        ConsoleView(environment: .init(store: store, mode: .network))
    }
}
