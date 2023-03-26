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
        WindowGroup(id: "WelcomeView") {
            WelcomeView(remoteLoggerViewModel: remoteLoggerViewModel)
        }
        .windowStyle(.hiddenTitleBar)

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
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}

private func closeWelcomeWindow() {
    NSApp.windows
        .first { $0.identifier?.rawValue.contains("WelcomeView") ?? false }?
        .close()
}
