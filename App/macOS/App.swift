// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@main
struct App: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup {
            PulseDocumentViewer()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .handlesExternalEvents(matching: ["file"])
    }
}
