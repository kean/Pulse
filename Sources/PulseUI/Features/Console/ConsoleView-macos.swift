// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleContainerViewModel

    public init(store: LoggerStore = .default) {
        _viewModel = StateObject(wrappedValue: ConsoleContainerViewModel(store: store))
    }

    #warning("TODO: add more toolbar items")
    public var body: some View {
//        VStack(spacing: 0) {
//            Divider()
            HStack(spacing: 0) {
                NavigationView {
                    MainPanelView(viewModel: viewModel, mode: viewModel.mode)
                        .frame(minWidth: 320)
                        .toolbar {
                            //                ToolbarItemGroup(placement: .navigation) {
                            //                    ConsoleToolbarModePickerView(model: viewModel.mode)
                            //                }
                            //                ToolbarItemGroup(placement: .principal) {
                            //                    if let client = viewModel.remote.client {
                            //                        RemoteLoggerClientStatusView(client: client)
                            //                        RemoteLoggerTooglePlayButton(client: client)
                            //                        ConsoleNowView(model: viewModel.toolbar)
                            //                        Button(action: client.clear, label: {
                            //                            Label("Clear", systemImage: "trash")
                            //                        }).help("Remove All Messages (⌘K)")
                            //                    }
                            //                }
                            //                ToolbarItem {
                            //                    Spacer()
                            //                }
                            ToolbarItemGroup(placement: .automatic) {
                                //                    ConsoleToolbarSearchBar(model: viewModel)
                                ConsoleToolbarToggleOnlyErrorsButton(viewModel: viewModel.toolbar)
                                ConsoleToolbarToggleFiltersButton(viewModel: viewModel.toolbar)
                                ConsoleToolbarModePickerButton(viewModel: viewModel.mode)
                                //                    ConsoleToolbarToggleVerticalView(model: viewModel.toolbar)
                            }
                        }
                }
                FiltersPanelView(viewModel: viewModel, tooblar: viewModel.toolbar)
            }
//        }
    }
}

private struct MainPanelView: View {
    var viewModel: ConsoleContainerViewModel
    @ObservedObject var mode: ConsoleModePickerViewModel

    var body: some View {
        if mode.isNetworkOnly {
            NetworkPanelView(viewModel: viewModel.network)
        } else {
            ConsolePanelView(viewModel: viewModel.console)
        }
    }
}

private struct ConsolePanelView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        List {
            ConsoleMessagesForEach(store: viewModel.store, messages: viewModel.messages)
        }.listStyle(.sidebar)
        .overlay(tableOverlay)
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.messages.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }
}

private struct NetworkPanelView: View {
    @ObservedObject var viewModel: NetworkViewModel

    var body: some View {
        List {
            NetworkMessagesForEach(store: viewModel.store, entities: viewModel.entities)
        }
        .overlay(tableOverlay)
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.entities.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }
}

private struct FiltersPanelView: View {
    let viewModel: ConsoleContainerViewModel
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
    let viewModel: ConsoleContainerViewModel
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

// MARK: ViewModel

private final class ConsoleContainerViewModel: ObservableObject {
    let console: ConsoleViewModel
    let network: NetworkViewModel
    let toolbar = ConsoleToolbarViewModel()
    let mode = ConsoleModePickerViewModel()

    private var cancellables: [AnyCancellable] = []

    public init(store: LoggerStore) {
        self.console = ConsoleViewModel(store: store)
        self.network = NetworkViewModel(store: store)

        toolbar.$isOnlyErrors.sink { [weak self] in
            self?.console.isOnlyErrors = $0
            self?.network.isOnlyErrors = $0
        }.store(in: &cancellables)
    }
}

private final class ConsoleModePickerViewModel: ObservableObject {
    @Published var isNetworkOnly = false
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            NavigationView {
                ConsoleView(store: .mock)
            }
            NavigationView {
                ConsoleView(store: .mock)
            }.environment(\.colorScheme, .dark)
        }
    }
}
#endif
#endif
