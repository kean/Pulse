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
                }.frame(width: proxy.size.width * 0.6)
                NavigationView {
                    ConsoleMenuView(viewModel: viewModel)
                        .padding()
                }
            }
            .backport.navigationTitle("Console")
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
        }
    }
}

#warning("TODO: udpate filter button deign and show proper fitler based on type + enable quick filters at least")
#warning("TODO: implement quick filters replacing date filters")
#warning("TODO: fix naviation to store info (provide focus area)")
private struct ConsoleMenuView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isPresentingFilters = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $viewModel.isOnlyErrors) {
                    LabelBackport("Errors Only", systemImage: "exclamationmark.octagon")
                }
                Toggle(isOn: Binding(get: { viewModel.mode == .network }, set: { _ in viewModel.toggleMode() })) {
                    LabelBackport("Network Only", systemImage: "arrow.down.circle")
                }
                NavigationLink(destination: destinationFilters) {
//                Button(action: { isPresentingFilters = true }) {
                    LabelBackport("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            Section {
                NavigationLink(destination: destinationSettings) {
                    LabelBackport("Settings", systemImage: "gear")
                }
                if #available(tvOS 14, *) {
                    NavigationLink(destination: destinationStoreDetails) {
                        LabelBackport("Store Info", systemImage: "info.circle")
                    }
                }
            }
            if !viewModel.store.isArchive {
                Section {
                    if #available(tvOS 15, *) {
                        Button(role: .destructive, action: viewModel.store.removeAll) {
                            Label("Remove Logs", systemImage: "trash")
                        }
                    } else {
                        Button(action: viewModel.store.removeAll) {
                            LabelBackport("Remove Logs", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private var destinationSettings: some View {
        SettingsView(store: viewModel.store)
            .padding()
    }

    @available(tvOS 14, *)
    private var destinationStoreDetails: some View {
        StoreDetailsView(source: .store(viewModel.store))
            .padding()
    }

    private var destinationFilters: some View {
        ConsoleMessageFiltersView(
            viewModel: viewModel.searchCriteriaViewModel,
            sharedCriteriaViewModel: viewModel.sharedSearchCriteriaViewModel,
            isPresented: $isPresentingFilters
        )
        .padding()
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
