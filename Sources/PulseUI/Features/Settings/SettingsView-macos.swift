// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import Pulse

@available(macOS 13, *)
struct SettingsView: View {
    @State private var isPresentingShareStoreView = false
    @State private var shareItems: ShareItems?

    @Environment(\.store) private var store
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        List {
            if !UserSettings.shared.isRemoteLoggingHidden {
                if #available(macOS 15, *), store === RemoteLogger.shared.store {
                    RemoteLoggerSettingsView(viewModel: .shared)
                } else {
                    Text("Not available")
                        .foregroundColor(.secondary)
                }
            }
            Section("Store") {
                // TODO: load this info async
                //                if #available(macOS 13, *), let info = try? store.info() {
                //                    LoggerStoreSizeChart(info: info, sizeLimit: store.configuration.sizeLimit)
                //                }
            }

            Section {
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.storeURL])
                    }
                    if !store.isReadonly {
                        Button("Remove Logs") {
                            store.removeAll()
                        }
                    }
                }
            }
        }.listStyle(.sidebar).scrollContentBackground(.hidden)
    }
}

// MARK: - Preview

#if DEBUG
@available(macOS 13, *)
#Preview {
    SettingsView()
}
#endif
#endif
