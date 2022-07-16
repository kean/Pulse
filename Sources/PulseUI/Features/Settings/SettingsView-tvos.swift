// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(tvOS)
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var console: ConsoleViewModel

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
                Section {
                    ButtonRemoveAll(action: console.buttonRemoveAllMessagesTapped)
                        .disabled(console.messages.isEmpty)
                        .opacity(console.messages.isEmpty ? 0.33 : 1)
                }
            }
            if #available(tvOS 14.0, *) {
                Section {
                    if console.store === RemoteLogger.shared.store {
                        Section {
                            RemoteLoggerSettingsView(viewModel: .shared)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 800)
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

#endif
