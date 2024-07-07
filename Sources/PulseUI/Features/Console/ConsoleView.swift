// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import PulseComponents

extension ConsoleView {
    /// Initializes the console view.
    /// 
    /// - parameters:
    ///   - store: The store to display. By default, `LoggerStore/shared`.
    ///   - mode: The initial console mode. By default, ``ConsoleMode/all``. If you change
    ///   the mode to ``ConsoleMode/network``, the console will display the
    ///   network messages up on appearance.
    ///   - configuration: Configuration options to alter the UI behavior and settings.
    ///   - delegate: The delegate that allows you to customize multiple aspects
    ///   of the console view.
    public init(
        store: LoggerStore = .shared,
        mode: ConsoleMode = .all,
        configuration: ConsoleConfiguration = .default,
        delegate: ConsoleViewDelegate? = nil
    ) {
        self.init(environment: .init(store: store, mode: mode, configuration: configuration, delegate: delegate ?? DefaultConsoleViewDelegate()))
    }
}
