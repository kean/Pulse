// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Combine
import Pulse
import Network

#warning("use custom sheet to requset passcode like WiFi view")
#warning("add animation when connectings")
#warning("add details screen")
#warning("remove selected device from list of devices")
#warning("remove spinner and offset ffrom devices list")
#warning("(?) add constant spinner for devices")
#warning("display server icons (can we do that? what can we display?)")

@available(iOS 15, *)
struct RemoteLoggerSettingsView: View {
    @ObservedObject private var logger: RemoteLogger = .shared
    @ObservedObject var viewModel: RemoteLoggerSettingsViewModel
    
    var body: some View {
        Section {
            Toggle(isOn: $viewModel.isEnabled, label: {
                HStack {
#if !os(watchOS)
                    Image(systemName: "network")
#endif
                    Text("Remote Logging")
#if os(macOS)
                    Spacer()
#endif
                }
            })
            if let server = logger.servers.first(where: logger.isSelected) {
                RemoteLoggerSelectedDeviceView(server: server)
            }
        }
        .alert("Connect", isPresented: $viewModel.isEnteringPasscode, actions: {
            SecureField("Passcode", text: $viewModel.passcode)
            Button("Connect", action: { viewModel.connect?() })
            Button("Cancel", role: .cancel, action: {})
        }, message: {
            Text("Please enter the passcode")
        })
        if viewModel.isEnabled {
            Section(header: Text("Devices")) {
                if let error = logger.browserError {
                    RemoteLoggerErrorView(error: error)
                } else {
                    if !viewModel.servers.isEmpty {
#if os(macOS) || os(iOS)
                        ForEach(viewModel.servers, content: makeServerView)
#else
                        List(viewModel.servers, rowContent: makeServerView)
#endif
                    } else {
                        progressView
                    }
                }
            }
        }
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
    
    @ViewBuilder
    private func makeServerView(for server: RemoteLoggerServerViewModel) -> some View {
        Button(action: server.connect) {
            HStack {
                if server.isSelected {
                    if viewModel.isConnected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: 21, height: 36, alignment: .center)
                    } else {
#if os(macOS)
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 15, height: 44, alignment: .leading)
                            .scaleEffect(0.5)
#else
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 21, height: 36, alignment: .leading)
#endif
                    }
                } else {
                    Rectangle()
                        .hidden()
                        .frame(width: 21, height: 36, alignment: .center)
                }
                Text(server.name)
                    .lineLimit(1)
                Spacer()
            }
        }
        .foregroundColor(Color.primary)
        .frame(maxWidth: .infinity)
    }
}

struct RemoteLoggerSelectedDeviceView: View {
    @ObservedObject var logger: RemoteLogger = .shared
    let server: NWBrowser.Result

    var body: some View {
        VStack(alignment: .leading) {
            Text(server.name ?? "–")
            makeStatusView(for: logger.connectionState)
        }
    }

    private func makeStatusView(for state: RemoteLogger.ConnectionState) -> some View {
        HStack {
            Circle()
                .frame(width: 8, height: 8)
                .foregroundColor({
                    switch logger.connectionState {
                    case .connected: return Color.green
                    case .connecting: return Color.yellow
                    case .idle: return Color.gray
                    }
                }())
        }
    }
}

#warning("implemenet this")
struct RemogeLoggerServerDetailsView: View {
    let server: NWBrowser.Result

    var body: some View {
        Form {
            Text(server.name ?? "–")
        }
    }
}

final class RemoteLoggerSettingsViewModel: ObservableObject {
    @Published var isEnabled = false
    @Published var servers: [RemoteLoggerServerViewModel] = []
    @Published var isConnected = false
    @Published var isEnteringPasscode = false
    @Published var passcode = ""
    
    private let logger: RemoteLogger
    private var cancellables: [AnyCancellable] = []

    var connect: (() -> Void)?

    static var shared = RemoteLoggerSettingsViewModel()
    
    init(logger: RemoteLogger = .shared) {
        self.logger = logger
        
        isEnabled = logger.isEnabled
        
        $isEnabled.removeDuplicates().receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.didUpdateIsEnabled($0)
            }.store(in: &cancellables)
        
        logger.$servers.receive(on: DispatchQueue.main).sink { [weak self] servers in
            self?.refresh(servers: servers)
        }.store(in: &cancellables)
        
        logger.$connectionState.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.isConnected = $0 == .connected
        }.store(in: &cancellables)
    }
    
    private func didUpdateIsEnabled(_ isEnabled: Bool) {
        isEnabled ? logger.enable() : logger.disable()
    }
    
    private func refresh(servers: Set<NWBrowser.Result>) {
        self.servers = servers
            .map { server in
                RemoteLoggerServerViewModel(
                    id: server,
                    name: server.name ?? "–",
                    isSelected: logger.isSelected(server),
                    connect: { [weak self] in self?.connect(to: server) }
                )
            }
            .sorted { $0.name.caseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private func connect(to server: NWBrowser.Result) {
        if server.isProtected {
            if let passcode = logger.getPasscode(for: server) {
                logger.connect(to: server, passcode: passcode)
            } else {
                passcode = ""
                isEnteringPasscode = true
                connect = { [unowned self] in
                    logger.setPasscode(passcode, for: server)
                    logger.connect(to: server, passcode: passcode)
                }
            }
        } else {
            logger.connect(to: server)
        }
    }
}

struct RemoteLoggerServerViewModel: Identifiable {
    let id: AnyHashable
    let name: String
    let isSelected: Bool
    let connect: () -> Void
}

private extension NWBrowser.Result {
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
        List {
            RemoteLoggerSettingsView(viewModel: .shared)
        }
    }
}
#endif
