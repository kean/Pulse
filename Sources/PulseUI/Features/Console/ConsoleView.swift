// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

extension ConsoleView {
    /// Initializes the console view
    ///
    /// - parameters:
    ///   - store: The store to display. By default, `LoggerStore/shared`.
    ///   - mode: The console mode. By default, ``ConsoleMode/all``. If you change
    ///   the mode to ``ConsoleMode/network``, the console will only display the
    public init(store: LoggerStore = .shared, mode: ConsoleMode = .all) {
        self.init(environment: .init(store: store, mode: mode))
    }
}
