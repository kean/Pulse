// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(tvOS)

import SwiftUI
import CoreData
import Pulse
import Combine

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment
    @StateObject private var listViewModel: ConsoleListViewModel

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
        _listViewModel = StateObject(wrappedValue: .init(environment: environment, filters: environment.filters))
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack {
                List {
                    ConsoleListContentView()
                }

                // TODO: Not sure it's valid
                NavigationView {
                    Form {
                        ConsoleMenuView()
                    }.padding()
                }
                .frame(width: 700)
            }
            .navigationTitle(environment.title)
            .onAppear { listViewModel.isViewVisible = true }
            .onDisappear { listViewModel.isViewVisible = false }
        }
        .injecting(environment)
        .environmentObject(listViewModel)
    }
}

private struct ConsoleMenuView: View {
    @EnvironmentObject private var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

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
        if !(store.options.contains(.readonly)) {
            Section {
                NavigationLink(destination: destinationStoreDetails) {
                    Label("Store Info", systemImage: "info.circle")
                }
                Button(role: .destructive, action: {
                    environment.index.clear()
                    store.removeAll()
                }, label: {
                    Label("Remove Logs", systemImage: "trash")
                })
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
        ConsoleFiltersView().padding()
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
