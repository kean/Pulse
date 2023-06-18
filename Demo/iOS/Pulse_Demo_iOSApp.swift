// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseUI

@main
struct PulseDemo_iOS: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ConsoleView(store: .demo)
            }
        }
    }
}
