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
            TabView {
                NavigationView {
                    WebSocketDemoView()
                }
                .tabItem {
                    Label("WebSocket", systemImage: "arrow.up.arrow.down.circle")
                }
                
                NavigationView {
                    ConsoleView(store: .shared)
                }
                .tabItem {
                    Label("Console", systemImage: "list.bullet.rectangle")
                }
            }
        }
    }
}

@MainActor
private final class AppViewModel: ObservableObject {
    init() {
        // Use shared store for demo
        LoggerStore.shared = .demo
    }
}
