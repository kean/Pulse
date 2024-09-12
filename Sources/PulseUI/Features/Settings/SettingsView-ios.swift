// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import Pulse
import UniformTypeIdentifiers

@available(iOS 15, visionOS 1.0, *)
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
            Section(header: Text("List headers"), footer: Text("These headers will be included in the list view")) {
                ForEach(settings.displayHeaders, id: \.self) {
                    Text($0)
                }
                .onDelete { indices in
                    settings.displayHeaders.remove(atOffsets: indices)
                }
                HStack {
                    TextField("New Header", text: $newHeaderName)
                    Button(action: {
                        withAnimation {
                            settings.displayHeaders.append(newHeaderName)
                            newHeaderName = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityLabel("Add header")
                    }
                    .disabled(newHeaderName.isEmpty)
                }
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
@available(iOS 15, visionOS 1.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(store: StorePreview.store!)
                .environmentObject(UserSettings.shared)
                .injecting(ConsoleEnvironment(store: StorePreview.store!))
                .navigationTitle("Settings")
        }
    }
}
#endif

#endif
