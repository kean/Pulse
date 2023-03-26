// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import AppKit
import SwiftUI

@main
struct App: SwiftUI.App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup(id: "WelcomeView") {
            WelcomeView()
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup {
            PulseDocumentViewer()
                .onAppear {
                    NSApp.windows
                        .first { $0.identifier?.rawValue.contains("WelcomeView") ?? false }?
                        .close()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .handlesExternalEvents(matching: ["file"])
    }
}
