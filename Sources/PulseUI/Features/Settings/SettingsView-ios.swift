// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import UniformTypeIdentifiers

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
public struct SettingsView: View {
    private let store: LoggerStore
    @State private var newHeaderName = ""
    @EnvironmentObject private var settings: UserSettings
    @ObservedObject private var logger: RemoteLogger = .shared

    public init(store: LoggerStore = .shared) {
        self.store = store
    }

    public var body: some View {
        Form {
            if !UserSettings.shared.isRemoteLoggingHidden,
               store === RemoteLogger.shared.store {
                RemoteLoggerSettingsView(viewModel: .shared)
            }
            Section("Other") {
                NavigationLink(destination: StoreDetailsView(source: .store(store)), label: {
                    Text("Store Info")
                })
            }
        }
        .animation(.default, value: logger.selectedServerName)
        .animation(.default, value: logger.servers)
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    NavigationView {
        SettingsView(store: .mock)
            .environmentObject(UserSettings.shared)
            .injecting(ConsoleEnvironment(store: LoggerStore.mock))
            .navigationTitle("Settings")
    }
}
#endif

#endif
