// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }


    public var body: some View {
        _ConsoleView(viewModel: viewModel)
    }
}

struct _ConsoleView: View {
    let viewModel: ConsoleViewModel

    #warning("remove")
    @State private var selectedShareOutput: ShareOutput?

    var body: some View {
        _ConsoleListView(viewModel: viewModel)
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
            .navigationTitle(viewModel.title)
            .navigationBarItems(leading: leadingNavigationBarItems, trailing: trailingNavigationBarItems)
            .background(ConsoleRouterView(viewModel: viewModel, router: viewModel.router))
    }

    private var leadingNavigationBarItems: some View {
        viewModel.onDismiss.map {
            Button(action: $0) { Text("Close") }
        }
    }

    private var trailingNavigationBarItems: some View {
        HStack {
            if let _ = selectedShareOutput {
                ProgressView()
                    .frame(width: 27, height: 27)
            } else {
                Menu(content: {
                    Button(action: { share(as: .plainText) }) {
                        Label("Share as Text", systemImage: "square.and.arrow.up")
                    }
                    Button(action: { share(as: .html) }) {
                        Label("Share as HTML", systemImage: "square.and.arrow.up")
                    }
                }, label: {
                    Image(systemName: "square.and.arrow.up")
                })
                .disabled(selectedShareOutput != nil)
            }
            ConsoleContextMenu(viewModel: viewModel)
        }
    }

    private func share(as output: ShareOutput) {
        selectedShareOutput = output
        viewModel.prepareForSharing(as: output) { item in
            selectedShareOutput = nil
            viewModel.router.shareItems = item
        }
    }
}

private struct _ConsoleListView: View {
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
                .environment(\.defaultMinListRowHeight, 8) // TODO: refactor
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
        ConsoleListView(viewModel: viewModel.list)
        footerView
    }

    #warning("implement on other platforms?")
    @ViewBuilder
    private var footerView: some View {
        if #available(iOS 15, *), viewModel.searchCriteriaViewModel.criteria.shared.dates == .session, viewModel.list.order == .descending {
            Button(action: { viewModel.searchCriteriaViewModel.criteria.shared.dates.startDate = nil }) {
                Text("Show Previous Sessions")
                    .font(.subheadline)
                    .foregroundColor(Color.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .listRowSeparator(.hidden, edges: .bottom)
        }
    }
}

// MARK: - Previews

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(viewModel: .init(store: .mock))
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
