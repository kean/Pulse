// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

public struct MainView: View {
    @StateObject private var viewModel: MainViewModel
    @State private var isShowingSettings = false

    public init(store: LoggerStore = .default) {
        _viewModel = StateObject(wrappedValue: MainViewModel(store: store))
    }

    public var body: some View {
        HStack(spacing: 0) {
            ConsoleContainerViewPro(viewModel: viewModel, details: viewModel.details, toolbar: viewModel.toolbar)
            FiltersPanelView(viewModel: viewModel, tooblar: viewModel.toolbar)
        }
        .navigationTitle("Console")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gearshape")
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
                ConsoleToolbarToggleFiltersButton(viewModel: viewModel.toolbar)
                    .keyboardShortcut("f", modifiers: [.command, .option])
                ConsoleToolbarToggleVerticalView(viewModel: viewModel.toolbar)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: .init(store: viewModel.store), console: viewModel.console)
        }
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
            .background(NavigationTitleUpdater(title: "Requests", viewModel: viewModel.network.table))
        } else {
            ConsoleTableView(viewModel: viewModel.console.table, onSelected: {
                viewModel.details.select($0)
            })
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

private struct FiltersPanelView: View {
    let viewModel: MainViewModel
    @ObservedObject var tooblar: ConsoleToolbarViewModel

    var body: some View {
        if !tooblar.isFiltersPaneHidden {
            HStack(spacing: 0) {
                ExDivider()
                ConsoleContainerFiltersPanel(viewModel: viewModel, mode: viewModel.mode)
                    .frame(width: 200)
            }
        }
    }
}

private struct ConsoleContainerFiltersPanel: View {
    let viewModel: MainViewModel
    @ObservedObject var mode: ConsoleModePickerViewModel

    var body: some View {
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
        return Group {
            NavigationView {
                MainView(store: .mock)
            }
            NavigationView {
                MainView(store: .mock)
            }.environment(\.colorScheme, .dark)
        }
    }
}
#endif
#endif
