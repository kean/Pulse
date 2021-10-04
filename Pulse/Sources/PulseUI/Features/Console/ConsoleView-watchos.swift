// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(watchOS)
import WatchConnectivity

@available(watchOS 7.0, *)
public struct ConsoleView: View {
    @ObservedObject var model: ConsoleViewModel
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var isShowingFiltersView = false
    @State private var isShowingRemoveConfirmationAlert = false
    @State private var isStoreArchived = false
    @State private var isRemoteLoggingLinkActive = false

    public init(store: LoggerStore = .default) {
        self.model = ConsoleViewModel(store: store)
    }

    init(model: ConsoleViewModel) {
        self.model = model
    }

    public var body: some View {
        List {
            Button(action: model.tranferStore) {
                Label(model.fileTransferStatus.title, systemImage: "square.and.arrow.up")
            }.disabled(model.fileTransferStatus.isButtonDisabled)
            if let model = model.remoteLoggerViewModel {
                NavigationLink(destination: _RemoteLoggingSettingsView(model: model)) {
                    Button(action: { isRemoteLoggingLinkActive = true }) {
                        Label("Remote Logging", systemImage: "network")
                    }
                }
            }
            Button(action: { isShowingFiltersView = true }) {
                Label("Quick Filters", systemImage: "line.horizontal.3.decrease.circle")
            }
            ConsoleMessagesForEach(context: model.context, messages: model.messages, searchCriteria: $model.searchCriteria)
        }
        .navigationTitle("Console")
        .toolbar {
            ToolbarItemGroup {
                ButtonRemoveAll(action: model.buttonRemoveAllMessagesTapped)
                    .disabled(model.messages.isEmpty)
                    .opacity(model.messages.isEmpty ? 0.33 : 1)
            }
        }
        .alert(item: $model.fileTransferError) { error in
            Alert(title: Text("Transfer Failed"), message: Text(error.message), dismissButton: .cancel(Text("Ok")))
        }
        .sheet(isPresented: $isShowingFiltersView) {
            List(model.quickFilters) { filter in
                Button(action: {
                    filter.action()
                    isShowingFiltersView = false
                }) {
                    Label(filter.title, systemImage: filter.imageName)
                        .foregroundColor(filter.title == "Reset" ? Color.red : nil)
                }
            }
        }
    }
}

@available(watchOS 7.0, *)
private struct _RemoteLoggingSettingsView: View {
    let model: RemoteLoggerSettingsViewModel

    var body: some View {
        Form {
            RemoteLoggerSettingsView(model: model)
        }
    }
}

#if DEBUG
@available(watchOS 7.0, *)
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            NavigationView {
                ConsoleView(model: .init(store: .mock))
            }
        }
    }
}
#endif
#endif
