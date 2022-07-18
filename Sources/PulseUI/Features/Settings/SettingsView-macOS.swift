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
        Form {
            if !viewModel.isReadonly {
                ButtonRemoveAll(action: console.buttonRemoveAllMessagesTapped)
                    .disabled(console.messages.isEmpty)
                    .opacity(console.messages.isEmpty ? 0.33 : 1)
            }
            if console.store === RemoteLogger.shared.store {
                Section {
                    RemoteLoggerSettingsView(viewModel: .shared)
                }
            }
        }
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
            SettingsView(viewModel: SettingsViewModel(store: .mock), console: ConsoleViewModel(store: .mock))
        }
    }
}
#endif
#endif

// MARK: - Helpers
#if os(iOS) || os(watchOS) || os(tvOS)

struct ButtonRemoveAll: View {
    let action: () -> Void

    var body: some View {
#if os(watchOS)
        let title = "Remove All"
#else
        let title = "Remove Messages"
#endif
        ButtonRemove(title: title, alert: "Are you sure you want to remove all recorded messages?", action: action)
    }
}

struct ButtonRemove: View {
    let title: String
    let alert: String
    let action: () -> Void

    var body: some View {
        let button =
        Button(action: action) {
#if os(watchOS)
            Label(title, systemImage: "trash")
#else
            HStack {
                Image(systemName: "trash")
                Text(title)
            }
#endif
        }

#if os(watchOS)
        button
#else
        button.foregroundColor(.red)
#endif
    }
}

#endif
