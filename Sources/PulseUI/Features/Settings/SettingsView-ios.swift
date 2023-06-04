// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS)
import UniformTypeIdentifiers

@available(iOS 15, *)
public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    @EnvironmentObject private var settings: UserSettings

    public init(store: LoggerStore = .shared) {
        // TODO: Fix ownership
        self.viewModel = SettingsViewModel(store: store)
    }

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Stepper("Line Limit: \(settings.lineLimit)", value: $settings.lineLimit, in: 1...20)
            }
            Section(header: Text("General")) {
                Toggle("Link Detection", isOn: $settings.isLinkDetectionEnabled)
            }
            if viewModel.isRemoteLoggingAvailable {
                RemoteLoggerSettingsView(viewModel: .shared)
            }
        }
    }
}

#if DEBUG
@available(iOS 15, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(viewModel: .init(store: .mock))
        }
    }
}
#endif

#endif
