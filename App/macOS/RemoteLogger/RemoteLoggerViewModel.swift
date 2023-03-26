// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Cocoa
import Pulse
import SwiftUI
import Combine

final class RemoteLoggerViewModel: ObservableObject {
    static let shared = RemoteLoggerViewModel()
    
    @Published var isRemoteLoggingEnabled: Bool = true
    @Published private(set) var clients: [RemoteLoggerClient] = []
    
    private let server: RemoteLoggerServer
    private var cancellables: [AnyCancellable] = []
    
    init(server: RemoteLoggerServer = .shared) {
        self.server = server
        
        $isRemoteLoggingEnabled.removeDuplicates().receive(on: DispatchQueue.main)
            .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in
                self?.didUpdateIsEnabled($0)
            }.store(in: &cancellables)

        display(clients: Array(server.clients.values))
        
        server.$clients.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] in
            self?.display(clients: Array($0.values))
        }.store(in: &cancellables)
    }
    
    private func display(clients: [RemoteLoggerClient]) {
        self.clients = Array(clients).sorted {
            ($0.deviceInfo.name, $0.appInfo.name ?? "") < ($1.deviceInfo.name, $1.appInfo.name ?? "")
        }
    }

    private func didUpdateIsEnabled(_ isEnabled: Bool) {
        isEnabled ? server.enable() : server.disable()
    }
    
    func buttonStartLoggerTapped() {
        server.enable()
        isRemoteLoggingEnabled = true
    }
}

extension NSNotification.Name {
    static let hideWelcomeWindow = NSNotification.Name(rawValue: "hide-welcome-window")
}
