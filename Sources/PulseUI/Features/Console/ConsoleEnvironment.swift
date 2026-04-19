// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

/// Contains every dependency that the console views have.
///
/// - warning: It's marked with `ObservableObject` to make it possible to be used
/// with `@StateObject` and `@EnvironmentObject`, but it never changes.
package final class ConsoleEnvironment: ObservableObject {
    package let title: String
    package let store: LoggerStoreProtocol
    package let index: LoggerStoreIndex

    package let filters: ConsoleFiltersViewModel
    package let logCountObserver: ManagedObjectsCountObserver
    package let taskCountObserver: ManagedObjectsCountObserver

    package let router = ConsoleRouter()

    package let initialMode: ConsoleMode

    /// A delegate that allows integrators to customize how individual tasks
    /// are rendered. The console keeps a strong reference, so simple
    /// configuration objects can be passed in without holding them elsewhere.
    package var delegate: (any ConsoleDelegate)?

    @Published package var mode: ConsoleMode
    @Published package var listOptions: ConsoleListOptions = .init()

    package var bindingForNetworkMode: Binding<Bool> {
        Binding(get: {
            self.mode == .network
        }, set: {
            self.mode = $0 ? .network : .all
        })
    }

    private var cancellables: [AnyCancellable] = []

    package init(
        store: LoggerStoreProtocol,
        mode: ConsoleMode = .all,
        delegate: (any ConsoleDelegate)? = nil
    ) {
        self.store = store
        self.delegate = delegate
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

        func makeDefaultOptions() -> ConsoleListPredicateOptions {
            var options = ConsoleListPredicateOptions()
            if let sessionID = store.currentSessionID {
                options.sessions = [sessionID]
            }
            return options
        }

        if let store = store as? LoggerStore {
            self.index = LoggerStoreIndex(store: store)
        } else {
            self.index = LoggerStoreIndex(context: store.backgroundContext)
        }
        self.filters = ConsoleFiltersViewModel(options: makeDefaultOptions())

        self.logCountObserver = ManagedObjectsCountObserver(
            entity: LoggerMessageEntity.self,
            context: store.viewContext
        )

        self.taskCountObserver = ManagedObjectsCountObserver(
            entity: NetworkTaskEntity.self,
            context: store.viewContext
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

    private func refreshCountObservers(_ options: ConsoleListPredicateOptions) {
        func makePredicate(for mode: ConsoleMode) -> NSPredicate? {
            ConsoleDataSource.makePredicate(mode: mode, options: options)
        }
        logCountObserver.setPredicate(makePredicate(for: .logs))
        taskCountObserver.setPredicate(makePredicate(for: .network))
    }

    /// Returns the display options to apply to the given network task,
    /// consulting ``delegate`` and falling back to ``UserSettings/shared``.
    @MainActor
    package func listDisplayOptions(for task: NetworkTaskEntity) -> ConsoleListDisplaySettings {
        delegate?.console(listDisplayOptionsFor: task) ?? UserSettings.shared.listDisplayOptions
    }

    /// Returns the text for a header/footer field, redacted through the
    /// ``delegate`` when available. Numeric / enum fields (sizes, durations,
    /// status codes, etc.) are passed through unchanged.
    @MainActor
    package func makeInfoText(for field: ConsoleListDisplaySettings.TaskField, task: NetworkTaskEntity) -> String? {
        guard let value = task.makeInfoText(for: field) else { return nil }
        return redact(value, field: field, task: task)
    }

    @MainActor
    package func makeInfoItem(for field: ConsoleListDisplaySettings.TaskField, task: NetworkTaskEntity) -> NetworkTaskEntity.InfoItem? {
        guard let value = makeInfoText(for: field, task: task) else { return nil }
        return NetworkTaskEntity.InfoItem(field: field, value: value)
    }

    /// Returns the inspector's short title for a task, redacted through the
    /// ``delegate`` when available.
    @MainActor
    package func shortTitle(for task: NetworkTaskEntity) -> String {
        let options = listDisplayOptions(for: task)
        let value = task.getShortTitle(options: options)
        guard let delegate, !value.isEmpty else { return value }
        let field: ConsoleRedactionField = (options.content.showTaskDescription &&
                                            !(task.taskDescription ?? "").isEmpty) ? .taskDescription : .url
        return delegate.console(redact: value, field: field, for: task)
    }

    /// Returns the main cell content string, redacted through the ``delegate``
    /// when available.
    @MainActor
    package func formattedContent(for task: NetworkTaskEntity, settings: ConsoleListDisplaySettings.ContentSettings) -> String? {
        guard let value = task.getFormattedContent(settings: settings) else { return nil }
        guard let delegate else { return value }
        let redactionField: ConsoleRedactionField
        if settings.customText != nil {
            redactionField = .custom
        } else if settings.showTaskDescription,
                  let description = task.taskDescription, !description.isEmpty {
            redactionField = .taskDescription
        } else {
            redactionField = .url
        }
        return delegate.console(redact: value, field: redactionField, for: task)
    }

    @MainActor
    private func redact(_ value: String, field: ConsoleListDisplaySettings.TaskField, task: NetworkTaskEntity) -> String {
        guard let delegate else { return value }
        let redactionField: ConsoleRedactionField
        switch field {
        case .url: redactionField = .url
        case .host: redactionField = .host
        case .requestHeaderField(let name): redactionField = .requestHeader(name)
        case .responseHeaderField(let name): redactionField = .responseHeader(name)
        case .taskDescription: redactionField = .taskDescription
        case .custom: redactionField = .custom
        case .method, .requestSize, .responseSize, .responseContentType,
             .duration, .statusCode, .taskType:
            return value
        }
        return delegate.console(redact: value, field: redactionField, for: task)
    }

    package func removeAllLogs() {
        guard !store.isReadonly else {
            return
        }
        store.removeAll()
        index.clear()

#if os(iOS) || os(visionOS)
        runHapticFeedback(.success)
#endif
    }
}

public enum ConsoleMode: String, Sendable {
    /// Displays both messages and network tasks with the ability
    /// to switch between the two modes.
    case all
    /// Displays only regular messages.
    case logs
    /// Displays only network tasks.
    case network

    package var hasLogs: Bool { self == .all || self == .logs }
    package var hasNetwork: Bool { self == .all || self == .network }

    package func formattedCount(_ count: Int) -> String {
        let unit: String
        switch self {
        case .network: unit = count == 1 ? "Task" : "Tasks"
        case .logs: unit = count == 1 ? "Log" : "Logs"
        case .all: unit = count == 1 ? "Item" : "Items"
        }
        return "\(count) \(unit)"
    }

    package var entityName: String {
        switch self {
        case .all, .logs: return "\(LoggerMessageEntity.self)"
        case .network: return "\(NetworkTaskEntity.self)"
        }
    }
}

// MARK: Environment

private struct LoggerStoreKey: EnvironmentKey {
    static let defaultValue: LoggerStoreProtocol = LoggerStore.shared
}

private struct ConsoleRouterKey: EnvironmentKey {
    static let defaultValue: ConsoleRouter = .init()
}

extension EnvironmentValues {
    package var store: LoggerStoreProtocol {
        get { self[LoggerStoreKey.self] }
        set { self[LoggerStoreKey.self] = newValue }
    }

    package var router: ConsoleRouter {
        get { self[ConsoleRouterKey.self] }
        set { self[ConsoleRouterKey.self] = newValue }
    }
}

extension View {
    package func injecting(_ environment: ConsoleEnvironment) -> some View {
        self.background(
            ConsoleRouterView(router: environment.router)
        )
        // important: order
        .environmentObject(environment)
        .environmentObject(environment.filters)
        .environmentObject(UserSettings.shared)
        .environment(\.router, environment.router)
        .environment(\.store, environment.store)
        .environment(\.managedObjectContext, environment.store.viewContext)
    }
}
