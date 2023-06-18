// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(tvOS)

import SwiftUI
import Pulse

public struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    var store: LoggerStore { viewModel.store }

    public init(store: LoggerStore = .shared) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(store: store))
    }

    public var body: some View {
        Form {
            if store === RemoteLogger.shared.store {
                RemoteLoggerSettingsView(viewModel: .shared)
            }
            Section {
                NavigationLink(destination: StoreDetailsView(source: .store(viewModel.store))) {
                    Text("Store Info")
                }
                if !(store.options.contains(.readonly)) {
                    Button(role: .destructive, action: viewModel.buttonRemoveAllMessagesTapped) {
                        Text("Remove Logs")
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .frame(maxWidth: 800)
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
