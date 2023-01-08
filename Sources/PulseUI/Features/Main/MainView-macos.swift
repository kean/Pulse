// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: remoev MainViewModel and ConsoleContainerView")
#warning("TODO: experiemnt with different navigation styles on macos")
#warning("TODO: show message details in the details and metadata in main panel")
#warning("TDO: move search button somewhere else")
#warning("TODO: fill-out filter button when custom selected")

#warning("TODO: can we reuse more with iOS?")

#if os(macOS)

public struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var isShowingSettings = false
    @State private var isShowingShareSheet = false
    @State private var shareItems: ShareItems?
 
    public init(store: LoggerStore = .shared) {
        _viewModel = StateObject(wrappedValue: MainViewModel(store: store))
    }

    public var body: some View {
        contents
            .navigationTitle("Console")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    Button(action: { isShowingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .popover(isPresented: $isShowingShareSheet, arrowEdge: .top) {
                        ShareStoreView(store: viewModel.store, isPresented: $isShowingShareSheet) { item in
                            isShowingShareSheet = false
                            DispatchQueue.main.async {
                                shareItems = item
                            }
                        }
                    }
                    .popover(item: $shareItems) { item in
                        ShareView(item)
                            .fixedSize()
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(viewModel: .init(store: viewModel.store))
            }
            .onDisappear { viewModel.freeMemory() }
    }

    @ViewBuilder
    private var contents: some View {
        if #available(macOS 13.0, *) {
            ConsoleContainerView(viewModel: viewModel, details: viewModel.details)
        } else {
            LegacyConsoleContainerView(viewModel: viewModel, details: viewModel.details)
        }
    }

    static let contentColumnWidth: CGFloat = 280
}

#warning("TODO: this is incomplete")
#warning("TODO: try to implement using selection https://stackoverflow.com/questions/72778176/swiftui-navigationsplitview-reset-detail-view-when-sidebar-selection-changes")

@available(macOS 13.0, *)
private struct ConsoleContainerView: View {
    var viewModel: MainViewModel
    @ObservedObject var details: ConsoleDetailsRouterViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            sidebar: {
                MainPanelView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: MainView.contentColumnWidth, ideal: 420, max: 640)
            },
            content: {
                ConsoleMessageDetailsRouter(viewModel: details)
                    .navigationSplitViewColumnWidth(MainView.contentColumnWidth)
            },
            detail: {
                PlaceholderView(imageName: "questionmark.circle", title: "No Selection")
            }
        )
    }
}

private struct LegacyConsoleContainerView: View {
    var viewModel: MainViewModel
    @ObservedObject var details: ConsoleDetailsRouterViewModel

    var body: some View {
        NavigationView {
            MainPanelView(viewModel: viewModel)
                .frame(minWidth: 320, idealWidth: 320, maxWidth: 600, minHeight: 120, idealHeight: 480, maxHeight: .infinity)
            ConsoleMessageDetailsRouter(viewModel: details)
                .frame(minWidth: 430, idealWidth: 500, maxWidth: 600, minHeight: 320, idealHeight: 480, maxHeight: .infinity)
            EmptyView()
        }
    }
}

private struct MainPanelView: View {
    let viewModel: MainViewModel

    var body: some View {
        VStack(spacing: 0) {
            content
            ConsoleToolbarSearchBar(viewModel: viewModel)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    // TODO: Refactor
                    viewModel.toolbar.isSearchBarActive = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                        viewModel.searchBar.onFind.send()
                    }
                }) {
                    Image(systemName: "magnifyingglass")
                }.keyboardShortcut("f")
                ConsoleToolbarToggleOnlyErrorsButton(viewModel: viewModel.toolbar)
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                ConsoleToolbarModePickerButton(viewModel: viewModel.console)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                FilterPopoverToolbarButton(viewModel: viewModel.console)
                    .keyboardShortcut("f", modifiers: [.command, .option])
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ConsoleTableView(viewModel: viewModel.console.table, onSelected: {
            viewModel.details.select($0)
        })
        .onAppear(perform: viewModel.console.onAppear)
        .onDisappear(perform: viewModel.console.onDisappear)
        .background(NavigationTitleUpdater(title: viewModel.console.mode == .network ? "Requests" : "Messages", viewModel: viewModel.console.table))
    }
}

private struct ConsoleToolbarSearchBar: View {
    let viewModel: MainViewModel
    @ObservedObject var toolbar: ConsoleToolbarViewModel
    @ObservedObject var searchBar: ConsoleSearchBarViewModel

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        self.toolbar = viewModel.toolbar
        self.searchBar = viewModel.searchBar
    }

    var body: some View {
        if toolbar.isSearchBarActive {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    SearchBar(title: "Filter", text: $searchBar.text, onFind: searchBar.onFind, onEditingChanged: { isEditing in
                        toolbar.isSearchBarActive = isEditing
                    }, onReturn: { })
                    .frame(maxWidth: toolbar.isSearchBarActive ? 320 : 200)
                    Spacer()
                }.padding(6)
            }
        }
    }
}

private struct FilterPopoverToolbarButton: View {
    let viewModel: ConsoleViewModel
    @State private var isFilterPresented = false

    var body: some View {
        Button(action: { isFilterPresented.toggle() }, label: {
            Image(systemName: isFilterPresented ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                .foregroundColor(isFilterPresented ? .accentColor : .secondary)
        })
        .help("Toggle Filters Panel (⌥⌘F)")
        .popover(isPresented: $isFilterPresented, arrowEdge: .top) {
            filters.frame(width: Filters.preferredWidth).padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var filters: some View {
        switch viewModel.mode {
        case .all:
            ConsoleMessageFiltersView(viewModel: viewModel.searchCriteriaViewModel, sharedCriteriaViewModel: viewModel.sharedSearchCriteriaViewModel)
        case .network:
            NetworkFiltersView(viewModel: viewModel.networkSearchCriteriaViewModel, sharedCriteriaViewModel: viewModel.sharedSearchCriteriaViewModel)
        }
    }
}

private struct ConsoleToolbarModePickerButton: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        Button(action: viewModel.toggleMode) {
            Image(systemName: viewModel.mode == .network ? "paperplane.fill" : "paperplane")
                .foregroundColor(viewModel.mode == .network ? Color.accentColor : Color.secondary)
        }.help("Automatically Scroll to Recent Messages (⇧⌘N)")
    }
}

private struct NavigationTitleUpdater: View {
    let title: String
    @ObservedObject var viewModel: ConsoleTableViewModel

    var body: some View {
        EmptyView().navigationSubtitle(message)
    }

    private var message: String {
        let count = viewModel.entities.count
        let title = count % 10 == 1 ? String(title.dropLast()) : title
        return "\(count) \(title)"
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(store: .mock)
            .previewLayout(.fixed(width: 1200, height: 800))
    }
}
#endif
#endif
