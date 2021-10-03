// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

#if os(tvOS)
import UniformTypeIdentifiers

@available(tvOS 14.0, *)
struct SettingsView: View {
    @ObservedObject var model: SettingsViewModel
    @ObservedObject var console: ConsoleViewModel

    @State var isSponsorAlertShown = false

    var body: some View {
        NavigationView {
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
                Section(footer: Text("Pulse is funded by the community contributions.")) {
                    Button(action: {
                        isSponsorAlertShown = true
                    }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(Color.pink)
                            Text("Sponsor")
                                .foregroundColor(Color.primary)
                            Spacer()
                            Image(systemName: "link")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: 800)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert(isPresented: $isSponsorAlertShown, content: {
            Alert(title: Text("Sponsor"), message: Text("Please visit https://github.com/sponsors/kean to sponsor"), dismissButton: .cancel(Text("Ok")))
        })
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
