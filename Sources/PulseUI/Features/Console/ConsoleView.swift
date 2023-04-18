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

extension View {
    func injecting(_ environment: ConsoleEnvironment) -> some View {
        self.background(ConsoleRouterView()) // important: order
            .environmentObject(environment)
            .environmentObject(environment.router)
            .environment(\.router, environment.router)
            .environment(\.store, environment.store)
            .environment(\.managedObjectContext, environment.store.viewContext)
    }
}

// MARK: Environment

private struct LoggerStoreKey: EnvironmentKey {
    static let defaultValue: LoggerStore = .shared
}

private struct ConsoleRouterKey: EnvironmentKey {
    static let defaultValue: ConsoleRouter = .init()
}

extension EnvironmentValues {
    var store: LoggerStore {
        get { self[LoggerStoreKey.self] }
        set { self[LoggerStoreKey.self] = newValue }
    }

    var router: ConsoleRouter {
        get { self[ConsoleRouterKey.self] }
        set { self[ConsoleRouterKey.self] = newValue }
    }
}
