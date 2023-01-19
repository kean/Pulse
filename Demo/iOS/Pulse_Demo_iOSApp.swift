// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import PulseUI

@main
struct Pulse_Demo_iOSApp: App {
    var body: some Scene {
//        let _ = testProxy()
        WindowGroup {
            NavigationView {
                ConsoleView(store: .demo)
            }
        }
    }
}

var task: URLSessionDataTask?

private func testProxy() {
//    Experimental.URLSessionProxy.shared.isEnabled = true
    URLSessionProxyDelegate.enableAutomaticRegistration()

    let session = URLSession(configuration: .default, delegate: MockSessionDelegate(), delegateQueue: nil)

    let task = session.downloadTask(with: URLRequest(url: URL(string: "https://github.com/kean/Nuke/archive/refs/tags/11.0.0.zip")!))
//    task = session.dataTask(with: URL(string: "https://github.com/CreateAPI/Get")!)
    task.resume()
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
