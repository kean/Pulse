// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

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
        ConsoleContainerViewPro(viewModel: viewModel, details: viewModel.details, toolbar: viewModel.toolbar)
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
                    ConsoleToolbarModePickerButton(viewModel: viewModel.mode)
                        .keyboardShortcut("n", modifiers: [.command, .shift])
                    FilterPopoverToolbarButton(viewModel: viewModel, mode: viewModel.mode)
                        .keyboardShortcut("f", modifiers: [.command, .option])
                    ConsoleToolbarToggleVerticalView(viewModel: viewModel.toolbar)
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(viewModel: .init(store: viewModel.store))
            }
            .onDisappear { viewModel.freeMemory() }
    }
}

private struct ConsoleContainerViewPro: View {
    var viewModel: MainViewModel
    @ObservedObject var details: ConsoleDetailsRouterViewModel
    @ObservedObject var toolbar: ConsoleToolbarViewModel

    var body: some View {
        NotSplitView(
            MainPanelView(viewModel: viewModel, mode: viewModel.mode)
                .frame(minWidth: 320, idealWidth: 320, maxWidth: .infinity, minHeight: 120, idealHeight: 480, maxHeight: .infinity, alignment: .center),
            ConsoleMessageDetailsRouter(viewModel: details)
                .frame(minWidth: 430, idealWidth: 500, maxWidth: .infinity, minHeight: 320, idealHeight: 480, maxHeight: .infinity, alignment: .center),
            isPanelTwoCollaped: viewModel.details.viewModel == nil,
            isVertical: toolbar.isVertical
        )
    }
}

private struct MainPanelView: View {
    var viewModel: MainViewModel
    @ObservedObject var mode: ConsoleModePickerViewModel

    var body: some View {
        VStack(spacing: 0) {
            content
            ConsoleToolbarSearchBar(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var content: some View {
        if mode.isNetworkOnly {
            ConsoleTableView(viewModel: viewModel.network.table, onSelected: {
                viewModel.details.select($0)
            })
            .onAppear(perform: viewModel.network.onAppear)
            .onDisappear(perform: viewModel.network.onDisappear)
            .background(NavigationTitleUpdater(title: "Requests", viewModel: viewModel.network.table))
        } else {
            ConsoleTableView(viewModel: viewModel.console.table, onSelected: {
                viewModel.details.select($0)
            })
            .onAppear(perform: viewModel.console.onAppear)
            .onDisappear(perform: viewModel.console.onDisappear)
            .background(NavigationTitleUpdater(title: "Messages", viewModel: viewModel.console.table))
        }
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
    let viewModel: MainViewModel
    @ObservedObject var mode: ConsoleModePickerViewModel
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
        if mode.isNetworkOnly {
            NetworkFiltersView(viewModel: viewModel.network.searchCriteria)
        } else {
            ConsoleFiltersView(viewModel: viewModel.console.searchCriteria)
        }
    }
}

private struct ConsoleToolbarModePickerButton: View {
    @ObservedObject var viewModel: ConsoleModePickerViewModel

    var body: some View {
        Button(action: { viewModel.isNetworkOnly.toggle() }) {
            Image(systemName: viewModel.isNetworkOnly ? "network" : "network")
                .foregroundColor(viewModel.isNetworkOnly ? Color.accentColor : Color.secondary)
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
        NavigationView {
            MainView(store: .mock)
        }
    }
}
#endif
#endif
