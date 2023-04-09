// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

extension ConsoleView {
    public init(store: LoggerStore = .shared, mode: ConsoleMode = .all) {
        self.init(viewModel: .init(store: store, mode: mode))
    }
}

extension View {
    func injectingEnvironment(_ viewModel: ConsoleViewModel) -> some View {
        self.environmentObject(viewModel)
            .environment(\.store, viewModel.store)
            .environment(\.managedObjectContext, viewModel.store.viewContext)
    }
}

// Create an environment key
private struct LoggerStoreKey: EnvironmentKey {
    static let defaultValue: LoggerStore = .shared
}

// ## Introduce new value to EnvironmentValues
extension EnvironmentValues {
    var store: LoggerStore {
        get { self[LoggerStoreKey.self] }
        set { self[LoggerStoreKey.self] = newValue }
    }
}
