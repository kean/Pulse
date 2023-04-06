// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

extension ConsoleView {
    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }
}
