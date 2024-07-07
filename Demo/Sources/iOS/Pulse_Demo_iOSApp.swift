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
                ConsoleView(store: .demo)
            }
        }
    }
}

private final class AppViewModel: ObservableObject {
    let log = OSLog(subsystem: "app", category: "AppViewModel")
    
    init() {
//        URLSessionProxyDelegate.enableAutomaticRegistration()
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
//            sendRequest()
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(6)) {
//            sendRequest()
//        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(9)) {
//            sendRequest()
//        }
    }
}

private func sendRequest() {
    let session = URLSession(configuration: .default)
    let task = session.dataTask(with: URLRequest(url: URL(string: "https://github.com/kean/Nuke/archive/refs/tags/11.0.0.zip")!))
    task.resume()
}
