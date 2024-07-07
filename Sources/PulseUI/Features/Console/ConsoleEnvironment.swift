// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import CoreData
import Combine
import SwiftUI
import Pulse
import PulseComponents

/// Contains every dependency that the console views have.
///
/// - warning: It's marked with `ObservableObject` to make it possible to be used
/// with `@StateObject` and `@EnvironmentObject`, but it never changes.
@MainActor
final class ConsoleEnvironment: ObservableObject {
    let title: String
    let store: LoggerStore
    let index: LoggerStoreIndex

    let filters: ConsoleFiltersViewModel
    let logCountObserver: ManagedObjectsCountObserver
    let taskCountObserver: ManagedObjectsCountObserver

    let router = ConsoleRouter()

    let initialMode: ConsoleMode
    let delegate: ConsoleViewDelegate
    let configuration: ConsoleConfiguration

    @Published var mode: ConsoleMode
    @Published var listOptions: ConsoleListOptions = .init()

    var bindingForNetworkMode: Binding<Bool> {
        Binding(get: {
            self.mode == .network
        }, set: {
            self.mode = $0 ? .network : .all
        })
    }

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: ConsoleMode = .all, configuration: ConsoleConfiguration = .default, delegate: ConsoleViewDelegate = DefaultConsoleViewDelegate()) {
        self.store = store
        switch mode {
        case .all: self.title = "Console"
        case .logs: self.title = "Logs"
        case .network: self.title = "Network"
        }
        self.initialMode = mode

        switch mode {
        case .all: self.mode = UserSettings.shared.mode
        case .logs: self.mode = .logs
        case .network: self.mode = .network
        }

        self.delegate = delegate
        self.configuration = configuration

        func makeDefaultOptions() -> ConsoleDataSource.PredicateOptions {
            var options = ConsoleDataSource.PredicateOptions()
            options.filters.shared.sessions.selection = [store.session.id]
            return options
        }

        self.index = LoggerStoreIndex(store: store)
        self.filters = ConsoleFiltersViewModel(options: makeDefaultOptions())

        self.logCountObserver = ManagedObjectsCountObserver(
            entity: LoggerMessageEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: false)
        )

        self.taskCountObserver = ManagedObjectsCountObserver(
            entity: NetworkTaskEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: false)
        )

        bind()
    }

    private func bind() {
        $mode.sink { [weak self] in
            self?.filters.mode = $0
        }.store(in: &cancellables)

        $mode.dropFirst().sink {
            UserSettings.shared.mode = $0
        }.store(in: &cancellables)

        filters.$options.sink { [weak self] in
            self?.refreshCountObservers($0)
        }.store(in: &cancellables)
    }

    private func refreshCountObservers(_ options: ConsoleDataSource.PredicateOptions) {
        func makePredicate(for mode: ConsoleMode) -> NSPredicate? {
            ConsoleDataSource.makePredicate(mode: mode, options: options)
        }
        logCountObserver.setPredicate(makePredicate(for: .logs))
        taskCountObserver.setPredicate(makePredicate(for: .network))
    }

    func removeAllLogs() {
        store.removeAll()
        index.clear()

#if os(iOS) || os(visionOS)
        runHapticFeedback(.success)
#endif
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

extension View {
    func injecting(_ environment: ConsoleEnvironment) -> some View {
        self.background(ConsoleRouterView()) // important: order
            .environmentObject(environment)
            .environmentObject(environment.router)
            .environmentObject(environment.index)
            .environmentObject(environment.filters)
            .environmentObject(UserSettings.shared)
            .environment(\.router, environment.router)
            .environment(\.store, environment.store)
            .environment(\.managedObjectContext, environment.store.viewContext)
    }
}
