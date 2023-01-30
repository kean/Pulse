// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseUI

#warning("update")

@main
struct Pulse_Demo_macOSApp: App {
    var body: some Scene {
        WindowGroup {
//            ConsoleView(store: .mock)
            ConsoleView(store: .demo)
        }
    }
}
