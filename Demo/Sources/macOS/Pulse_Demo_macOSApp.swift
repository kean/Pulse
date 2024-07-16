// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseUI

@main
struct Pulse_Demo_macOSApp: App {
    var body: some Scene {
        WindowGroup {
            ConsoleView(store: .demo)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
