// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Combine
import Pulse
import Network

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
