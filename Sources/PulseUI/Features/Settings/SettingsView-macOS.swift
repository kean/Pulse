// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(macOS)
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var console: ConsoleViewModel
    @Environment(\.presentationMode) var presentationMode
    var store: LoggerStore { console.store }

    @State private var isDocumentBrowserPresented = false

    public init(store: LoggerStore = .default) {
        self.viewModel = SettingsViewModel(store: store)
        self.console = ConsoleViewModel(store: store)
    }

    init(viewModel: SettingsViewModel, console: ConsoleViewModel) {
        self.viewModel = viewModel
        self.console = console
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
                    if !viewModel.isReadonly {
                        ButtonRemoveAll(action: console.buttonRemoveAllMessagesTapped)
                            .disabled(console.entities.isEmpty)
                            .opacity(console.entities.isEmpty ? 0.33 : 1)
                    }
                }
                Section(header: Text("Remote Logging")) {
                    if console.store === RemoteLogger.shared.store {
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

// MARK: - Settings

final class SettingsViewModel: ObservableObject {
    private let store: LoggerStore

    var onDismiss: (() -> Void)?

    init(store: LoggerStore) {
        self.store = store
    }

    var isReadonly: Bool {
        store.isReadonly
    }
}

// MARK: - Preview

#if DEBUG
struct ConsoleSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SettingsView(viewModel: SettingsViewModel(store: .default), console: ConsoleViewModel(store: .default))
        }
    }
}
#endif
#endif
