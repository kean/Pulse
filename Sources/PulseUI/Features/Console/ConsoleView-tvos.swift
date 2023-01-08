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
        HStack {
            List {
                Section {
                    Toggle(isOn: $viewModel.isOnlyErrors) {
                        LabelBackport("Errors Only", systemImage: "exclamationmark.octagon")
                    }
                    Toggle(isOn: Binding(get: { viewModel.mode == .network }, set: { viewModel.mode = $0 ? .network : .all })) {
                        LabelBackport("Network Only", systemImage: "paperplane")
                    }
                }
                Section {
                    NavigationLink(destination: SettingsView(store: viewModel.store)) {
                        LabelBackport("Settings", systemImage: "gear")
                    }
                    if #available(tvOS 14, *) {
                        NavigationLink(destination: StoreDetailsView(source: .store(viewModel.store))) {
                            LabelBackport("Store Info", systemImage: "info.circle")
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .frame(maxWidth: 540)

            List {
                ConsoleMessagesForEach(messages: viewModel.entities)
            }
        }
        .backport.navigationTitle("Console")
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
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
