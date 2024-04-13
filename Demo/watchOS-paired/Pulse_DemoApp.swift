// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import PulseUI
import WatchConnectivity
import OSLog

@main
struct PulseDemo_watchOS: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ConsoleView(store: .demo)
            }
        }
    }
}

// MARK: - iOS Integratoin

private final class AppViewModel: NSObject, ObservableObject, WCSessionDelegate {
    let log = OSLog(subsystem: "app", category: "AppViewModel")

    override init() {
        super.init()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        os_log("WCSession.activationDidCompleteWith(state: %{public}@, error: %{public}@)", log: log, "\(activationState)", String(describing: error))
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        os_log("WCSession.didFinishFileTransfer(error: %{public}@)", log: log, String(describing:  error))

        LoggerStore.session(session, didFinish: fileTransfer, error: error)
    }
}

extension WCSessionActivationState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notActivated: return ".notActivated"
        case .inactive: return ".inactive"
        case .activated: return ".activated"
        @unknown default: return "unknown"
        }
    }
}
