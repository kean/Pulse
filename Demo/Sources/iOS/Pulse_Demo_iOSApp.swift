// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import PulseUI
import OSLog

@main
struct PulseDemo_iOS: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ConsoleView(store: .shared)
            }
        }
    }
}

private final class AppViewModel: ObservableObject {
    let log = OSLog(subsystem: "app", category: "AppViewModel")

    init() {
        // URLSessionProxyDelegate.enableAutomaticRegistration()
        // URLSessionProxy.enable()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            sendRequest()
        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(6)) {
//            sendRequest()
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(9)) {
//            sendRequest()
//        }
    }
}


private func sendRequest() {
    testClosures()

//    let task = session.dataTask(with: URLRequest(url: URL(string: "https://github.com/kean/Nuke/archive/refs/tags/11.0.0.zip")!))
//    task.resume()
}



private func testClosures() {
    let session = NetworkLogger.URLSession(configuration: .default)
    let task = session.dataTask(with: URLRequest(url: URL(string: "https://api.github.com/repos/octocat/Spoon-Knife/issues?per_page=2")!)) { data, _, _ in
        NSLog("didFinish: \(data?.count)")
    }
    task.resume()
}

private func testSwiftConcurrency() {
    Task {
        let demoDelegate = DemoSessionDelegate()
        let session = NetworkLogger.URLSession(configuration: .default, delegate: demoDelegate, delegateQueue: nil)
//        let session = NetworkLogger.URLSessionProxy(session: original)
        if #available(iOS 15.0, *) {
            let data = try await session.data(from: URL(string: "https://api.github.com/repos/octocat/Spoon-Knife/issues?per_page=2")!, delegate: demoDelegate)
            print(data.0.count)
        } else {
            // Fallback on earlier versions
        }
    }
}

private final class DemoSessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("here")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        print("here2")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        print("here3")
    }
}
