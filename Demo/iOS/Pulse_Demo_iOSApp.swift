//
//  Pulse_Demo_iOSApp.swift
//  Pulse Demo iOS
//
//  Created by Alexander Grebenyuk on 16.03.2021.
//  Copyright © 2021 kean. All rights reserved.
//

import SwiftUI
import PulseCore
import PulseUI

@main
struct Pulse_Demo_iOSApp: App {
    var body: some Scene {
        let _ = testProxy()
        WindowGroup {
            MainView(store: .mock)
        }
    }
}

var task: URLSessionDataTask?

private func testProxy() {
//    Experimental.URLSessionProxy.shared.isEnabled = true
    URLSessionProxyDelegate.enableAutomaticRegistration()

    let session = URLSession(configuration: .default, delegate: MockSessionDelegate(), delegateQueue: nil)
    task = session.dataTask(with: URL(string: "https://google.com")!)
    task?.resume()
}

private final class MockSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    var completion: ((URLSessionTask, Error?) -> Void)?

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        completion?(task, error)
    }
}
