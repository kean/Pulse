// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

extension ConsoleView {
    public init(store: LoggerStore = .shared, mode: ConsoleMode = .all) {
        self.init(environment: .init(store: store, mode: mode))
    }
}

extension ConsoleView {
    @available(*, deprecated, message: "Please use the default initializer and pass the mode instead")
    public static func network(store: LoggerStore = .shared) -> ConsoleView {
        ConsoleView(environment: .init(store: store, mode: .network))
    }
}
