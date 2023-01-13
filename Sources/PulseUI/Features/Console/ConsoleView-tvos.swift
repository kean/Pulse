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
    @State private var isShowingFiltersView = false
    @State private var isShowingRemoveConfirmationAlert = false
    @State private var isStoreArchived = false

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: ConsoleViewModel(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        GeometryReader { proxy in
            HStack {
                List {
                    ConsoleMessagesForEach(messages: viewModel.entities)
                }

                // TODO: Not sure it's valid
                NavigationView {
                    Form {
                        ConsoleMenuView(viewModel: viewModel)
                    }.padding()
                }
                .frame(width: 700)
            }
            .navigationTitle(viewModel.title)
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
        }
    }
}

private struct ConsoleMenuView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        Section {
            Toggle(isOn: $viewModel.isOnlyErrors) {
                Label("Errors Only", systemImage: "exclamationmark.octagon")
            }
            Toggle(isOn: Binding(get: { viewModel.mode == .network }, set: { _ in viewModel.toggleMode() })) {
                Label("Network Only", systemImage: "arrow.down.circle")
            }
            NavigationLink(destination: destinationFilters) {
                Label(viewModel.mode == .network ? "Network Filters" : "Message Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
        } header: { Text("Quick Filters") }
        if !viewModel.store.isArchive {
            Section {
                NavigationLink(destination: destinationStoreDetails) {
                    Label("Store Info", systemImage: "info.circle")
                }
                Button.destructive(action: viewModel.store.removeAll) {
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
        SettingsView(store: viewModel.store).padding()
    }

    private var destinationStoreDetails: some View {
        StoreDetailsView(source: .store(viewModel.store)).padding()
    }

    private var destinationFilters: some View {
        ConsoleSearchView(viewModel: viewModel.searchViewModel).padding()
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
