// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import AppKit
import SwiftUI
import PulseUI

@main
struct App: SwiftUI.App {
    @StateObject var remoteLoggerViewModel = RemoteLoggerViewModel()

    var body: some Scene {
        let _ = UserDefaults.standard.set(true, forKey: "pulse-is-running-standalone-macos-app")

        WindowGroup(id: "WelcomeView") {
            WelcomeView(remoteLoggerViewModel: remoteLoggerViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppCommands(remoteLoggerViewModel: remoteLoggerViewModel)
        }

        WindowGroup {
            PulseDocumentViewer()
                .onAppear(perform: closeWelcomeWindow)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .handlesExternalEvents(matching: ["file"])

        WindowGroup(id: "RemoteClient", for: RemoteLoggerClientInfo.self) { info in
            if let client = remoteLoggerViewModel.clients.first(where: { $0.id == info.wrappedValue?.id }) {
                ConsoleView(store: client.store)
                    .onAppear {
                        closeWelcomeWindow()
                        client.resume()
                    }
                    .onDisappear {
                        client.pause()
                    }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))

        Settings {
            SettingsView()
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var remoteLoggerViewModel: RemoteLoggerViewModel
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(before: .newItem) {
            Button("Open", action: openDocument).keyboardShortcut("o")
            Menu("Open Recent") {
                ForEach(NSDocumentController.shared.recentDocumentURLs, id: \.self) { url in
                    Button(action: { NSWorkspace.shared.open(url) }, label: {
                        Text(url.lastPathComponent)
                    })
                }
            }
            Menu("Open Device Logs") {
                ForEach(remoteLoggerViewModel.clients) { client in
                    Button(action: { openWindow(id: "RemoteClient", value: client.info) }) {
                        Text(client.info.deviceInfo.name) + Text(client.preferredSuffix ?? "")
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

private func closeWelcomeWindow() {
    NSApp.windows
        .first { $0.identifier?.rawValue.contains("WelcomeView") ?? false }?
        .close()
}
