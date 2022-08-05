// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(watchOS)

final class MainViewModel: ObservableObject {
    var store: LoggerStore { console.store }
    let console: ConsoleViewModel
    let settings: SettingsViewModel

    private var cancellables: [AnyCancellable] = []

    public init(store: LoggerStore) {
        self.console = ConsoleViewModel(store: store)
        self.settings = SettingsViewModel(store: store)
    }
}

#endif
