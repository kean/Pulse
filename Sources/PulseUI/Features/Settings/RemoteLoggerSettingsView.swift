// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Combine
import Pulse
import Network

@available(iOS 14.0, tvOS 14.0, *)
struct RemoteLoggerSettingsView: View {
    @ObservedObject var viewModel: RemoteLoggerSettingsViewModel
    
    var body: some View {
        Toggle(isOn: $viewModel.isEnabled, label: {
            HStack {
#if !os(watchOS)
                Image(systemName: "network")
#endif
                Text("Remote Logging")
            }
        })
        if viewModel.isEnabled {
            if !viewModel.servers.isEmpty {
#if os(macOS)
                ForEach(viewModel.servers, content: makeServerView)
#else
                List(viewModel.servers, rowContent: makeServerView)
#endif
            } else {
                progressView
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
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(width: 21, height: 36, alignment: .leading)
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
        }.foregroundColor(Color.primary)
            .frame(maxWidth: .infinity)
    }
}

@available(iOS 14.0, tvOS 14.0, *)
final class RemoteLoggerSettingsViewModel: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var servers: [RemoteLoggerServerViewModel] = []
    @Published var isConnected: Bool = false
    
    private let logger: RemoteLogger
    private var cancellables: [AnyCancellable] = []
    
    public static var shared = RemoteLoggerSettingsViewModel()
    
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
        logger.connect(to: server)
        refresh(servers: logger.servers)
    }
}

struct RemoteLoggerServerViewModel: Identifiable {
    let id: AnyHashable
    let name: String
    let isSelected: Bool
    let connect: () -> Void
}

@available(iOS 14.0, tvOS 14.0, *)
private extension NWBrowser.Result {
    var name: String? {
        switch endpoint {
        case .service(let name, _, _, _):
            return name
        default:
            return nil
        }
    }
}

#if DEBUG
struct RemoteLoggerSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 14.0, tvOS 14.0, *) {
            RemoteLoggerSettingsView(viewModel: .shared)
                .previewLayout(.sizeThatFits)
        }
    }
}
#endif
