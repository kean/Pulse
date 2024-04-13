// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import PulseUI
import WatchConnectivity
import OSLog

@main
struct PulseDemo_iOS: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ConsoleView(store: .demo)
            }
        }
    }
}

// MARK: - WatchOS Integration

private final class AppViewModel: NSObject, ObservableObject, WCSessionDelegate {
    let log = OSLog(subsystem: "app", category: "AppViewModel")

    override init() {
        super.init()

        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }

        // Uncomment to test `URLSessionProxyDelegate`:
        // testProxy()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        os_log("WCSession.activationDidCompleteWith(state: %{public}@, error: %{public}@)", log: log, "\(activationState)", String(describing: error))
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        os_log("WCSession.sessionDidBecomeInactive()", log: log)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        os_log("WCSession.sessionDidDeactivate()", log: log)
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        os_log("WCSession.didReceiveFile(url: %{public}@, metadata: %{public}@", log: log, String(describing: file.fileURL), String(describing:  file.metadata?.description))

        LoggerStore.session(session, didReceive: file)
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

// MARK: - URLSessionProxyDelegate Example

private func testProxy() {
//    Experimental.URLSessionProxy.shared.isEnabled = true
    URLSessionProxyDelegate.enableAutomaticRegistration()

    let session = URLSession(configuration: .default, delegate: MockSessionDelegate(), delegateQueue: nil)

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) {
        let task = session.dataTask(with: URLRequest(url: URL(string: "https://github.com/kean/Nuke/archive/refs/tags/11.0.0.zip")!))
        task.resume()
    }
}

private final class MockSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDownloadDelegate {
    var completion: ((URLSessionTask, Error?) -> Void)?

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        completion?(task, error)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        print("here")
    }
}
