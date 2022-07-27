// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(watchOS)
import WatchConnectivity

struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    @State private var isShowingRemoveConfirmationAlert = false
    @State private var isStoreArchived = false
    @State private var isRemoteLoggingLinkActive = false

    init(store: LoggerStore = .default) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            Button(action: viewModel.tranferStore) {
                Label(viewModel.fileTransferStatus.title, systemImage: "square.and.arrow.up")
            }.disabled(viewModel.fileTransferStatus.isButtonDisabled)
            if viewModel.store === RemoteLogger.shared.store {
                NavigationLink(destination: _RemoteLoggingSettingsView(viewModel: .shared)) {
                    Button(action: { isRemoteLoggingLinkActive = true }) {
                        Label("Remote Logging", systemImage: "network")
                    }
                }
            }

            Button(action: { viewModel.isOnlyErrors.toggle() }) {
                Label("Show Errors", systemImage: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
            }.listRowBackground(viewModel.isOnlyErrors ? Color.blue.cornerRadius(8) : nil)

            Button(action: { viewModel.isOnlyNetwork.toggle() }) {
                Label("Show Requests", systemImage: "network")
            }.listRowBackground(viewModel.isOnlyNetwork ? Color.blue.cornerRadius(8) : nil)

            ConsoleMessagesForEach(store: viewModel.store, messages: viewModel.entities)
        }
        .navigationTitle("Console")
        .toolbar {
            ToolbarItemGroup {
                ButtonRemoveAll(action: viewModel.buttonRemoveAllMessagesTapped)
                    .disabled(viewModel.entities.isEmpty)
                    .opacity(viewModel.entities.isEmpty ? 0.33 : 1)
                    .padding(.bottom, 4)
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .alert(item: $viewModel.fileTransferError) { error in
            Alert(title: Text("Transfer Failed"), message: Text(error.message), dismissButton: .cancel(Text("Ok")))
        }
    }
}

private struct _RemoteLoggingSettingsView: View {
    let viewModel: RemoteLoggerSettingsViewModel

    var body: some View {
        Form {
            RemoteLoggerSettingsView(viewModel: viewModel)
        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            NavigationView {
                ConsoleView(viewModel: .init(store: .mock))
            }
        }
    }
}
#endif
#endif
