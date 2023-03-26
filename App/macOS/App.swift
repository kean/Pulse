// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI

@main
struct App: SwiftUI.App {
    @State private var isWelcomeViewHidden = true

    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
        .windowStyle(.hiddenTitleBar)

        WindowGroup {
            PulseDocumentViewer()
        }
        .handlesExternalEvents(matching: ["file"])
    }
}
