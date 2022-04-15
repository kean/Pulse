// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(tvOS)
import UniformTypeIdentifiers

@available(tvOS 14.0, *)
struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var console: ConsoleViewModel

    public init(store: LoggerStore = .default) {
        self.model = SettingsViewModel(store: store)
        self.console = ConsoleViewModel(store: store, contentType: .all)
    }
    
    init(model: SettingsViewModel, console: ConsoleViewModel) {
        self.model = model
        self.console = console
    }
    
    public var body: some View {
        Form {
            if !model.isReadonly {
                Section {
                    ButtonRemoveAll(action: console.buttonRemoveAllMessagesTapped)
                        .disabled(console.messages.isEmpty)
                        .opacity(console.messages.isEmpty ? 0.33 : 1)
                }
            }
            Section {
                if let model = console.remoteLoggerViewModel {
                    Section {
                        RemoteLoggerSettingsView(model: model)
                    }
                }
            }
        }
        .frame(maxWidth: 800)
    }
}

// MARK: - Settings

@available(tvOS 14.0, *)
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
