// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if !os(macOS)

extension ConsoleView {
    /// Initializes the console view.
    ///
    /// - parameters:
    ///   - store: The store to display. By default, `LoggerStore/shared`.
    ///   - mode: The initial console mode. By default, ``ConsoleMode/all``. If you change
    ///   the mode to ``ConsoleMode/network``, the console will display the
    ///   network messages up on appearance.
    ///   - delegate: An optional ``ConsoleDelegate`` that can customize how
    ///   individual tasks are rendered — e.g., vary
    ///   ``ConsoleListDisplaySettings`` per task. By default, the console
    ///   uses ``UserSettings/shared``.
    public init(
        store: LoggerStore = .shared,
        mode: ConsoleMode = .all,
        delegate: (any ConsoleDelegate)? = nil
    ) {
        self.init(environment: .init(store: store, mode: mode, delegate: delegate))
    }
}

#endif
