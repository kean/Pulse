// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

public final class RequestsLogger: @unchecked Sendable {
    public struct Configuration {
        public var redacted: Redacted = Redacted()

        /// Gets called when the logger receives an event. You can use it to
        /// modify the event before it is stored in order, for example, filter
        /// out some sensitive information. If you return `nil`, the event
        /// is ignored completely.
        public var willHandleEvent: @Sendable (LoggerStore.Event) -> LoggerStore.Event? = { $0 }

        /// Initializes the default configuration.
        public init() {}
    }

    private var store: LoggerStore { _store ?? .shared }
    private let _store: LoggerStore?

    private let configuration: Configuration
    private let patterns: Redacted.Patterns

    /// A shared requests logger.
    ///
    /// You can configure a logger by creating a new instance and setting it as
    /// a shared logger:
    ///
    /// ```swift
    /// RequestsLogger.shared = RequestsLogger {
    ///     $0.excludedHosts = ["github.com"]
    /// }
    /// ```
    ///
    /// The best place to do it is at the app launch.
    public static var shared: RequestsLogger {
        get { _shared.value }
        set { _shared.value = newValue }
    }
    private static let _shared = Mutex(RequestsLogger())

    /// Initializes the requests logger.
    ///
    /// - parameters:
    ///   - store: The target store for network requests.
    ///   - configuration: The store configuration.
    public init(store: LoggerStore? = nil, configuration: Configuration = .init()) {
        self._store = store
        self.configuration = configuration
        self.patterns = configuration.redacted.patterns()
    }

    /// Initializes and configures the requests logger.
    public convenience init(store: LoggerStore? = nil, _ configure: (inout Configuration) -> Void) {
        var configuration = Configuration()
        configure(&configuration)
        self.init(store: store, configuration: configuration)
    }

    /// Stores the network request.
    ///
    /// - note: If you want to store incremental updates to the task, use
    /// `NetworkLogger` instead.
    public func storeRequest(
        _ request: URLRequest,
        response: URLResponse?,
        error: Swift.Error?,
        data: Data?,
        metrics: URLSessionTaskMetrics? = nil,
        label: String? = nil,
        taskDescription: String? = nil
    ) {
        send(.networkTaskCompleted(.init(
            taskId: UUID(),
            taskType: .dataTask,
            createdAt: Date(),
            originalRequest: NetworkLogger.Request(request),
            currentRequest: NetworkLogger.Request(request),
            response: response.map(NetworkLogger.Response.init),
            error: error.map(NetworkLogger.ResponseError.init),
            requestBody: request.httpBody ?? request.httpBodyStreamData(),
            responseBody: data,
            metrics: metrics.map(NetworkLogger.Metrics.init),
            label: label,
            taskDescription: taskDescription
        )))
    }

    private func send(_ event: LoggerStore.Event) {
        guard !patterns.isFilteringNeeded || patterns.filter(event) else {
            return
        }
        guard let event = configuration.willHandleEvent(patterns.preprocess(event)) else {
            return
        }
        store.handle(event)
    }
}
