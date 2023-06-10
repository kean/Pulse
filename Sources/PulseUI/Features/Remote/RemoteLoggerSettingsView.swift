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
#if os(macOS) || os(iOS)
                        ForEach(servers, content: makeServerView)
#else
                        List(servers, rowContent: makeServerView)
#endif
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
#if !os(watchOS)
                Text(Image(systemName: "wifi"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Color.blue)
                    .cornerRadius(6)
#endif
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remote Logging")
                    Text("Requires [Pulse for Mac](https://testflight.apple.com/join/1jcanE3q)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
#if os(macOS)
//                Spacer()
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

final class RemoteLoggerSettingsViewModel: ObservableObject {
    @Published var isEnabled = false
    @Published var pendingPasscodeProtectedServer: RemoteLoggerServerViewModel?
    @Published var isShowingConnectionError = false
    private(set) var connectionError: RemoteLogger.ConnectionError?

    private let logger: RemoteLogger
    private var cancellables: [AnyCancellable] = []

    static var shared = RemoteLoggerSettingsViewModel()
    
    init(logger: RemoteLogger = .shared) {
        self.logger = logger
        
        isEnabled = logger.isEnabled
        
        $isEnabled.dropFirst().removeDuplicates().receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.didUpdateIsEnabled($0)
            }.store(in: &cancellables)
    }
    
    private func didUpdateIsEnabled(_ isEnabled: Bool) {
        isEnabled ? logger.enable() : logger.disable()
    }

    func connect(to viewModel: RemoteLoggerServerViewModel) {
        let server = viewModel.server
        if server.isProtected {
            if let passcode = server.name.flatMap(logger.getPasscode) {
                _connect(to: server, passcode: passcode)
            } else {
                pendingPasscodeProtectedServer = viewModel
            }
        } else {
            _connect(to: server)
        }
    }

    func connect(to viewModel: RemoteLoggerServerViewModel, passcode: String) {
        _connect(to: viewModel.server, passcode: passcode)
    }

    private func _connect(to server: NWBrowser.Result, passcode: String? = nil) {
        logger.connect(to: server, passcode: passcode) {
            switch $0 {
            case .success:
                break
            case .failure(let error):
                self.connectionError = error
                self.isShowingConnectionError = true
            }
        }
    }
}

struct RemoteLoggerServerViewModel: Identifiable {
    var id: NWBrowser.Result { server }
    let server: NWBrowser.Result
    let name: String
    let isSelected: Bool
}

extension NWBrowser.Result {
    var name: String? {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        default:
            return nil
        }
    }

    var isProtected: Bool {
        switch metadata {
        case .bonjour(let record):
            return record["protected"].map { Bool($0) } == true
        case .none:
            return false
        @unknown default:
            return false
        }
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
