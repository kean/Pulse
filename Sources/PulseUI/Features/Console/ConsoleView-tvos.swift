// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(tvOS)

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack {
                List {
                    ConsoleListContentView(viewModel: viewModel.listViewModel)
                }

                // TODO: Not sure it's valid
                NavigationView {
                    Form {
                        ConsoleMenuView(viewModel: viewModel)
                    }.padding()
                }
                .frame(width: 700)
            }
            .injectingEnvironment(viewModel)
            .navigationTitle(viewModel.title)
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
        }
    }
}

private struct ConsoleMenuView: View {
    let store: LoggerStore
    let consoleViewModel: ConsoleViewModel
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    @ObservedObject var router: ConsoleRouter

    init(viewModel: ConsoleViewModel) {
        self.consoleViewModel = viewModel
        self.store = viewModel.store
        self.viewModel = viewModel.searchCriteriaViewModel
        self.router = viewModel.router
    }

    var body: some View {
        Section {
            Toggle(isOn: $viewModel.options.isOnlyErrors) {
                Label("Errors Only", systemImage: "exclamationmark.octagon")
            }
            Toggle(isOn: consoleViewModel.bindingForNetworkMode) {
                Label("Network Only", systemImage: "arrow.down.circle")
            }
            NavigationLink(destination: destinationFilters) {
                Label(consoleViewModel.bindingForNetworkMode.wrappedValue ? "Network Filters" : "Message Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
        } header: { Text("Quick Filters") }
        if !store.isArchive {
            Section {
                NavigationLink(destination: destinationStoreDetails) {
                    Label("Store Info", systemImage: "info.circle")
                }
                Button.destructive {
                    consoleViewModel.index.clear()
                    store.removeAll()
                } label: {
                    Label("Remove Logs", systemImage: "trash")
                }
            } header: { Text("Store") }
        }
        Section {
            NavigationLink(destination: destinationSettings) {
                Label("Settings", systemImage: "gear")
            }
        } header: { Text("Settings") }
    }

    private var destinationSettings: some View {
        SettingsView(store: store).padding()
    }

    private var destinationStoreDetails: some View {
        StoreDetailsView(source: .store(store)).padding()
    }

    private var destinationFilters: some View {
        ConsoleSearchCriteriaView(viewModel: viewModel).padding()
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(store: .mock)
        }
    }
}
#endif
#endif
