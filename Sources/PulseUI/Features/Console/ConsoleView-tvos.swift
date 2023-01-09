// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(tvOS)

public struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFiltersView = false
    @State private var isShowingRemoveConfirmationAlert = false
    @State private var isStoreArchived = false

    public init(store: LoggerStore = .shared) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
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
            .backport.navigationTitle(viewModel.title)
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
                LabelBackport("Errors Only", systemImage: "exclamationmark.octagon")
            }
            Toggle(isOn: Binding(get: { viewModel.mode == .network }, set: { _ in viewModel.toggleMode() })) {
                LabelBackport("Network Only", systemImage: "arrow.down.circle")
            }
            NavigationLink(destination: destinationFilters) {
                LabelBackport(viewModel.mode == .network ? "Network Filters" : "Message Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
        } header: { Text("Quick Filters") }
        if !viewModel.store.isArchive {
            Section {
                if #available(tvOS 14, *) {
                    NavigationLink(destination: destinationStoreDetails) {
                        LabelBackport("Store Info", systemImage: "info.circle")
                    }
                }
                if #available(tvOS 15, *) {
                    Button(role: .destructive, action: viewModel.store.removeAll) {
                        Label("Remove Logs", systemImage: "trash")
                    }
                } else {
                    Button(action: viewModel.store.removeAll) {
                        LabelBackport("Remove Logs", systemImage: "trash")
                    }
                }
            } header: { Text("Store") }
        }
        Section {
            NavigationLink(destination: destinationSettings) {
                LabelBackport("Settings", systemImage: "gear")
            }
        } header: { Text("Settings") }
    }

    private var destinationSettings: some View {
        SettingsView(store: viewModel.store).padding()
    }

    @available(tvOS 14, *)
    private var destinationStoreDetails: some View {
        StoreDetailsView(source: .store(viewModel.store)).padding()
    }

    private var destinationFilters: some View {
        ConsoleFiltersView(viewModel: viewModel).padding()
    }
}

struct LabelBackport: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        if #available(tvOS 14.0, *) {
            Label(title, systemImage: systemImage)
        } else {
            HStack(spacing: 16) {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
    }
}

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
