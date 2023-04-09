// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        contents
            .injectingEnvironment(viewModel)
            .navigationTitle("")
    }

    @ViewBuilder
    private var contents: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView(sidebar: {
                ConsoleInspectorsView()
            }, detail: {
                NavigationStack {
                    ConsoleMainView(viewModel: viewModel)
                }
            })
        } else {
            NavigationView {
                ConsoleInspectorsView()
                ConsoleMainView(viewModel: viewModel)
            }
        }
    }
}

/// This view contains the console itself along with the details (no sidebar).
struct ConsoleMainView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false

    var body: some View {
        if isVertical {
            VSplitView {
                contentView
                detailsView.layoutPriority(1)
            }
        } else {
            HSplitView {
                contentView
                detailsView.layoutPriority(1)
            }
        }
    }

    private var contentView: some View {
        ConsoleLeftPanelView(viewModel: viewModel, searchBarViewModel: viewModel.searchBarViewModel)
    }

    private var detailsView: some View {
        ConsoleRightPanelView(viewModel: viewModel, router: viewModel.router, isVertical: $isVertical)
    }
}

private struct ConsoleLeftPanelView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var searchBarViewModel: ConsoleSearchBarViewModel

    @AppStorage("com-github-kean-pulse-display-mode") private var displayMode: ConsoleDisplayMode = .list
    @AppStorage("com-github-kean-pulse-is-now-enabled") private var isNowEnabled = true

    var body: some View {
        let content = ConsoleContentView(viewModel: viewModel, displayMode: displayMode)
            .frame(minWidth: 200, idealWidth: 400, minHeight: 120, idealHeight: 480)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    toolbarNavigationItems
                }
            }
        if #available(macOS 13, *) {
            content
                .searchable(text: $searchBarViewModel.text, tokens: $searchBarViewModel.tokens, token: {
                    if let image = $0.systemImage {
                        Label($0.title, systemImage: image)
                    } else {
                        Text($0.title)
                    }
                })
                .onSubmit(of: .search, viewModel.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
        } else {
            content
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search, viewModel.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
        }
    }

    @ViewBuilder
    private var toolbarNavigationItems: some View {
#if PULSE_STANDALONE_APP
        if let client = viewModel.client {
            RemoteLoggerClientStatusView(client: client)
            RemoteLoggerTooglePlayButton(client: client)
        } else if viewModel.store.isArchive {
            StoreStatusView(store: viewModel.store)
        }
#endif
        Picker("Mode", selection: $displayMode) {
            Label("List", systemImage: "list.bullet").tag(ConsoleDisplayMode.list)
            Label("Table", systemImage: "tablecells").tag(ConsoleDisplayMode.table)
            Label("Text", systemImage: "text.quote").tag(ConsoleDisplayMode.text)
        }.pickerStyle(.segmented)
        if !viewModel.store.isArchive {
            Toggle(isOn: $isNowEnabled) {
                Image(systemName: "clock")
            }
            Button(action: { viewModel.store.removeAll() }) {
                Image(systemName: "trash")
            }
        }
    }
}

private struct ConsoleRightPanelView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var router: ConsoleRouter
    @Binding var isVertical: Bool

    var body: some View {
        if router.selection != nil {
            ConsoleEntityDetailsRouterView(store: viewModel.store, router: viewModel.router, isVertical: $isVertical)
                .background(Color(UXColor.textBackgroundColor))
                .frame(minWidth: 400, idealWidth: 700, minHeight: 120, idealHeight: 480)
        }
    }
}

private struct ConsoleContentView: View {
    let viewModel: ConsoleViewModel
    let displayMode: ConsoleDisplayMode

    @State private var selectedObjectID: NSManagedObjectID? // Has to use for Table
    @State private var selection: ConsoleSelectedItem?
    @State private var shareItems: ShareItems?

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        VStack(spacing: 0) {
            if !isSearching {
                ConsoleToolbarView(viewModel: viewModel)
                Divider()
            }
            content
        }
        .onChange(of: selectedObjectID) {
            viewModel.router.selection = $0.map(ConsoleSelectedItem.entity)
        }
        .onChange(of: selection) {
            viewModel.router.selection = $0
        }
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            List(selection: $selection) {
                ConsoleSearchView(viewModel: viewModel.searchViewModel)
                    .buttonStyle(.plain)
            }
            .apply(addListContextMenu)
            .onAppear {
                // TODO: search should not depend on list
                viewModel.listViewModel.isViewVisible = true
                viewModel.searchViewModel.isViewVisible = true
            }
            .onDisappear {
                viewModel.listViewModel.isViewVisible = false
                viewModel.searchViewModel.isViewVisible = false
            }
        } else {
            switch displayMode {
            case .list:
                ScrollViewReader { proxy in
                    List(selection: $selection) {
                        ConsoleListContentView(viewModel: viewModel.listViewModel, proxy: proxy)
                    }
                    .environment(\.defaultMinListRowHeight, 1)
                    .apply(addListContextMenu)
                }
                .onAppear { viewModel.listViewModel.isViewVisible = true }
                .onDisappear { viewModel.listViewModel.isViewVisible = false }
            case .table:
                ConsoleTableView(viewModel: viewModel.tableViewModel, selection: $selectedObjectID)
                    .apply(addTableContextMenu)
                    .onAppear { viewModel.tableViewModel.isViewVisible = true }
                    .onDisappear { viewModel.tableViewModel.isViewVisible = false }
            case .text:
                ConsoleTextView(viewModel: viewModel.textViewModel)
                    .onAppear { viewModel.textViewModel.isViewVisible = true }
                    .onDisappear { viewModel.textViewModel.isViewVisible = false }
            }
        }
    }

    @ViewBuilder
    private func addTableContextMenu<T: View>(_ view: T) -> some View {
        if #available(macOS 13, *) {
            view.contextMenu(forSelectionType: NSManagedObjectID.self, menu: { _ in }) {
                $0.first.map(ConsoleSelectedItem.entity).map(makeDetailsView)?.showInWindow()
            }
        } else {
            view
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
            if let entity = try? viewModel.store.viewContext.existingObject(with: objectID) {
                ConsoleEntityStandaloneDetailsView(entity: entity)
                    .frame(minWidth: 400, idealWidth: 700, minHeight: 400, idealHeight: 480)
            }
        case .occurrence(let objectID, let occurrence):
            if let entity = try? viewModel.store.viewContext.existingObject(with: objectID) {
                ConsoleSearchResultView.makeDestination(for: occurrence, entity: entity)
                    .frame(minWidth: 400, idealWidth: 700, minHeight: 400, idealHeight: 480)
            }
        }
    }
}

private enum ConsoleDisplayMode: String {
    case table
    case list
    case text
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleView(store: .mock)
            .previewLayout(.fixed(width: 700, height: 400))
    }
}
#endif
#endif
