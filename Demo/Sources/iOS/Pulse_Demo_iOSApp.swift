// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import PulseUI
import PulseProxy

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

private final class AppViewModel: ObservableObject {
    init() {
        // - warning: If you are testing it, make sure to switch the demo to use
        // the shared store.

        // NetworkLogger.enableProxy()

        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
            sendRequest()
        }
    }
}


private func sendRequest() {
    // testSwiftConcurrency()

//    let task = session.dataTask(with: URLRequest(url: URL(string: "https://github.com/kean/Nuke/archive/refs/tags/11.0.0.zip")!))
//    task.resume()
}

private func testClosures() {
    let session = URLSessionProxy(configuration: .default)
    let task = session.dataTask(with: URLRequest(url: URL(string: "https://api.github.com/repos/octocat/Spoon-Knife/issues?per_page=2")!)) { data, _, _ in
        NSLog("didFinish: \(data?.count ?? 0)")
    }
    task.resume()
}

private func testSwiftConcurrency() {
    Task {
        let demoDelegate = DemoSessionDelegate()
        let session = URLSessionProxy(configuration: .default, delegate: demoDelegate, delegateQueue: nil)
//        let session = URLSession(configuration: .default)

        let (data, _) = try await session.data(from: URL(string: "https://api.github.com/repos/octocat/Spoon-Knife/issues?per_page=2")!) //, delegate: demoDelegate)
        NSLog("didFinish: \(data.count)")
    }
}

private final class DemoSessionDelegate: NSObject, URLSessionDelegate, URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        NSLog("[\(dataTask.taskIdentifier)] didReceive: \(data.count)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        NSLog("[\(task.taskIdentifier)] didFinishCollectingMetrics: \(metrics)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        NSLog("[\(task.taskIdentifier)] didCompleteWithError: \(String(describing: error))")
    }
}
