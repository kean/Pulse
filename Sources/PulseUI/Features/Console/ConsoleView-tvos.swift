// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(tvOS)

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack {
                List {
                    ConsoleListContentView(viewModel: environment.listViewModel)
                }

                // TODO: Not sure it's valid
                NavigationView {
                    Form {
                        ConsoleMenuView(environment: environment)
                    }.padding()
                }
                .frame(width: 700)
            }
            .injecting(environment)
            .navigationTitle(environment.title)
            .onAppear { environment.listViewModel.isViewVisible = true }
            .onDisappear { environment.listViewModel.isViewVisible = false }
        }
    }
}

private struct ConsoleMenuView: View {
    let store: LoggerStore
    let environment: ConsoleEnvironment
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.store = environment.store
        self.viewModel = environment.searchCriteriaViewModel
    }

    var body: some View {
        Section {
            Toggle(isOn: $viewModel.options.isOnlyErrors) {
                Label("Errors Only", systemImage: "exclamationmark.octagon")
            }
            Toggle(isOn: environment.bindingForNetworkMode) {
                Label("Network Only", systemImage: "arrow.down.circle")
            }
            NavigationLink(destination: destinationFilters) {
                Label(environment.bindingForNetworkMode.wrappedValue ? "Network Filters" : "Message Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
        } header: { Text("Quick Filters") }
        if !store.isArchive {
            Section {
                NavigationLink(destination: destinationStoreDetails) {
                    Label("Store Info", systemImage: "info.circle")
                }
                Button.destructive {
                    environment.index.clear()
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
