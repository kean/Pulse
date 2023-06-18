// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI
import Pulse

public struct SettingsView: View {
    private let store: LoggerStore

    @StateObject private var syncService: WatchConnectivityService = .shared
    @State private var isShowingShareView = false

    public init(store: LoggerStore = .shared) {
        self.store = store
    }

    public var body: some View {
        Form {
            Section {
                if store === RemoteLogger.shared.store {
#if targetEnvironment(simulator)
                    RemoteLoggerSettingsView(viewModel: .shared)
#else
                    RemoteLoggerSettingsView(viewModel: .shared)
                        .disabled(true)
                        .foregroundColor(.secondary)
                    Text("Not available on watchOS devices")
                        .foregroundColor(.secondary)
#endif
                }
            }
            Section {
                Button(action: { syncService.share(store: store) }) {
                    Text(syncService.state.title)
                }
                .disabled(syncService.isButtonDisabled)
                .alert(item: $syncService.error) { error in
                    Alert(title: Text("Transfer Failed"), message: Text(error.error.localizedDescription), dismissButton: .cancel(Text("Ok")))
                }
                
                if #available(watchOS 9, *) {
                    Button("Share Store") { isShowingShareView = true }
                }
            }
            Section {
                NavigationLink(destination: StoreDetailsView(source: .store(store))) {
                    Text("Store Info")
                }
                if !(store.options.contains(.readonly)) {
                    Button(role: .destructive, action: { store.removeAll() }) {
                        Text("Remove Logs")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $isShowingShareView) {
            if #available(watchOS 9, *) {
                NavigationView {
                    ShareStoreView() {
                        isShowingShareView = false
                    }
                }
            }
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(store: .mock)
        }.navigationViewStyle(.stack)
    }
}
#endif
#endif
