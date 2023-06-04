// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS)
import UniformTypeIdentifiers

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var newHeaderName = ""
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
                Section {
                    RemoteLoggerSettingsView(viewModel: .shared)
                }
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
        }
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(viewModel: .init(store: .mock))
        }
    }
}
#endif

#endif
