// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Combine
import Pulse
import Network

@available(iOS 15, *)
struct RemoteLoggerSettingsView: View {
    @ObservedObject private var logger: RemoteLogger = .shared
    @ObservedObject var viewModel: RemoteLoggerSettingsViewModel

    var body: some View {
        let servers = self.servers

        Section {
            toggleView
                .background(RemoteLoggerSettingsRouterView(viewModel: viewModel))
            if let server = logger.selectedServerName {
                RemoteLoggerSelectedDeviceView(name: server, server: servers.first(where: { $0.isSelected }))
            }
        }

        if viewModel.isEnabled {
            Section(header: Text("Devices")) {
                if let error = logger.browserError {
                    RemoteLoggerErrorView(error: error)
                } else {
                    if !servers.isEmpty {
                        ForEach(servers, content: makeServerView)
                    } else {
                        progressView
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var toggleView: some View {
        Toggle(isOn: $viewModel.isEnabled, label: {
            HStack(spacing: 12) {
#if os(watchOS)
                Text("Remote Logging")
#else
                Text(Image(systemName: "wifi"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.blue)
                    .cornerRadius(6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remote Logging")
                    Text("Requires [Pulse for Mac](https://testflight.apple.com/join/1jcanE3q)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
#endif
            }
        })
#if os(macOS)
        .toggleStyle(.switch)
#endif
#if os(iOS)
        .padding(.vertical, 2)
#endif
    }

    private var progressView: some View {
#if os(watchOS)
        ProgressView()
            .progressViewStyle(.circular)
            .frame(idealWidth: .infinity, alignment: .center)
#else
        HStack(spacing: 8) {
#if !os(macOS)
            ProgressView()
                .progressViewStyle(.circular)
#endif
            Text("Searching...")
                .foregroundColor(.secondary)
        }
#endif
    }

    private var servers: [RemoteLoggerServerViewModel] {
        logger.servers.map { server in
            RemoteLoggerServerViewModel(
                server: server,
                name: server.name ?? "–",
                isSelected: logger.isSelected(server)
            )
        }
        .sorted { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending }
    }

    @ViewBuilder
    private func makeServerView(for server: RemoteLoggerServerViewModel) -> some View {
        Button(action: { viewModel.connect(to: server) }) {
            HStack {
                Text(server.name)
                    .fontWeight(server.isSelected ? .medium : .regular)
                    .lineLimit(1)
                if server.isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                        .font(.system(size: 15, weight: .medium))
#if os(iOS)
                        .frame(width: 21, height: 36, alignment: .center)
#endif
                }
                Spacer()
                if server.server.isProtected {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.separator)
                }
            }
#if os(macOS)
            .contentShape(Rectangle())
#endif
        }
        .foregroundColor(Color.primary)
        .frame(maxWidth: .infinity)
#if os(macOS)
        .buttonStyle(.plain)
#endif
    }
}

@available(iOS 15, *)
struct RemoteLoggerSettingsRouterView: View {
    @ObservedObject private var logger: RemoteLogger = .shared
    @ObservedObject var viewModel: RemoteLoggerSettingsViewModel

    var body: some View {
        Text("").invisible()
            .sheet(item: $viewModel.pendingPasscodeProtectedServer, content: makeEnterPasswordView)
            .alert(isPresented: $viewModel.isShowingConnectionError, error: viewModel.connectionError) {
                Button("OK", role: .cancel) {
                    viewModel.isShowingConnectionError = false
                }
            }
    }

    @ViewBuilder
    private func makeEnterPasswordView(for server: RemoteLoggerServerViewModel) -> some View {
#if os(macOS)
        let view = RemoteLoggerEnterPasswordView(viewModel: viewModel, server: server)
            .padding()
        if #available(macOS 13, *) {
            view.formStyle(.grouped)
        } else {
            view
        }
#else
        NavigationView {
            RemoteLoggerEnterPasswordView(viewModel: viewModel, server: server)
        }
#endif
    }
}

#if DEBUG
@available(iOS 15, *)
struct RemoteLoggerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        List {
            RemoteLoggerSettingsView(viewModel: .init())
        }
#else
        NavigationView {
            List {
                RemoteLoggerSettingsView(viewModel: .init())
            }
            .navigationTitle("Settings")
        }
#endif
    }
}
#endif
