// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(macOS)
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    var store: LoggerStore { viewModel.store }

    @State private var isDocumentBrowserPresented = false

    public init(store: LoggerStore = .shared) {
        self.viewModel = SettingsViewModel(store: store)
    }

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack {
            List {
                HStack {
                    Text("Settings")
                        .font(.title)
                    Spacer()
                    Button("Close") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                Section(header: Text("Open Store")) {
                    Button("Open in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.storeURL])
                    }
                    Button("Open in Pulse Pro") {
                        NSWorkspace.shared.open(store.storeURL)
                    }
                }
                Section(header: Text("Manage Messages")) {
                    if !viewModel.isArchive {
                        ButtonRemoveAll(action: viewModel.buttonRemoveAllMessagesTapped)
                    }
                }
                Section(header: Text("Remote Logging")) {
                    if viewModel.isRemoteLoggingAvailable {
                        RemoteLoggerSettingsView(viewModel: .shared)
                    } else {
                        Text("Not available")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(width: 260, height: 400)
    }
}

// MARK: - Preview

#if DEBUG
struct ConsoleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: SettingsViewModel(store: .shared))
    }
}
#endif
#endif
