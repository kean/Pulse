// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A wrapper on top of ``LoggerStore`` that simplifies logging of network requests.
///
/// - note: ``NetworkLogger`` is used internally by ``URLSessionProxyDelegate`` and
/// should generally not be used directly.
public final class NetworkLogger: @unchecked Sendable {
    private let configuration: Configuration
    private var store: LoggerStore { _store ?? .shared }
    private let _store: LoggerStore?

    private let patterns: Redacted.Patterns

    private let lock = NSLock()

    /// A shared network logger.
    ///
    /// You can configure a logger by creating a new instance and setting it as
    /// a shared logger:
    ///
    /// ```swift
    /// NetworkLogger.shared = NetworkLogger {
    ///     $0.excludedHosts = ["github.com"]
    /// }
    /// ```
    ///
    /// The best place to do it is at the app launch.
    public static var shared: NetworkLogger {
        get { _shared.value }
        set { _shared.value = newValue }
    }
    private static let _shared = Mutex(NetworkLogger())

    /// The logger configuration.
    public struct Configuration: Sendable {
        /// A custom label to associated with stored messages.
        public var label: String?

        /// If enabled, the requests are not marked as completed until the decoding
        /// is done (see ``NetworkLogger/logTask(_:didFinishDecodingWithError:)``.
        /// If the request itself fails, the task completes immediately.
        public var isWaitingForDecoding = false

        public var redacted = Redacted()

        /// Gets called when the logger receives an event. You can use it to
        /// modify the event before it is stored in order, for example, filter
        /// out some sensitive information. If you return `nil`, the event
        /// is ignored completely.
        public var willHandleEvent: @Sendable (LoggerStore.Event) -> LoggerStore.Event? = { $0 }

        /// Initializes the default configuration.
        public init() {}
    }

    /// Initializes the network logger.
    ///
    /// - parameters:
    ///   - store: The target store for network requests.
    ///   - configuration: The store configuration.
    public init(store: LoggerStore? = nil, configuration: Configuration = .init()) {
        self._store = store
        self.configuration = configuration
        self.patterns = configuration.redacted.patterns()
    }

    /// Initializes and configures the network logger.
    public convenience init(store: LoggerStore? = nil, _ configure: (inout Configuration) -> Void) {
        var configuration = Configuration()
        configure(&configuration)
        self.init(store: store, configuration: configuration)
    }

    // MARK: Logging

    /// Logs the task creation (optional).
    public func logTaskCreated(_ task: URLSessionTask) {
        lock.lock()
        guard tasks[TaskKey(task: task)] == nil else {
            lock.unlock()
            return // Already registered
        }
        let context = context(for: task)
        lock.unlock()

        guard let originalRequest = task.originalRequest else { return }
        send(.networkTaskCreated(LoggerStore.Event.NetworkTaskCreated(
            taskId: context.taskId,
            taskType: NetworkLogger.TaskType(task: task),
            createdAt: Date(),
            originalRequest: .init(originalRequest),
            currentRequest: task.currentRequest.map(Request.init),
            label: configuration.label,
            taskDescription: task.taskDescription
        )))
    }

    /// Logs the task data that gets appended to the previously received chunks (required).
    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        let context = self.context(for: dataTask)
        context.data.append(data)
        lock.unlock()
    }

    public func logTask(_ task: URLSessionTask, didUpdateProgress progress: (completed: Int64, total: Int64)) {
        lock.lock()
        let context = self.context(for: task)
        lock.unlock()

        send(.networkTaskProgressUpdated(.init(
            taskId: context.taskId,
            url: task.originalRequest?.url,
            completedUnitCount: progress.completed,
            totalUnitCount: progress.total
        )))
    }

    /// Logs the task completion (required).
    public func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        guard error != nil || !configuration.isWaitingForDecoding else { return }
        _logTask(task, didCompleteWithError: error)
    }

    /// Logs the task metrics (optional).
    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        context(for: task).metrics = NetworkLogger.Metrics(metrics: metrics)
        lock.unlock()
    }

    /// Logs the task metrics (optional).
    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: NetworkLogger.Metrics) {
        lock.lock()
        context(for: task).metrics = metrics
        lock.unlock()
    }

    public func logTask(_ task: URLSessionTask, didFinishDecodingWithError error: Error?) {
        _logTask(task, didCompleteWithError: error)
    }

    private func _logTask(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let context = self.context(for: task)
        tasks[TaskKey(task: task)] = nil

        guard let originalRequest = task.originalRequest else {
            lock.unlock()
            return // This should never happen
        }

        let metrics = context.metrics
        let data = context.data
        lock.unlock()

        send(.networkTaskCompleted(.init(
            taskId: context.taskId,
            taskType: NetworkLogger.TaskType(task: task),
            createdAt: Date(),
            originalRequest: Request(originalRequest),
            currentRequest: task.currentRequest.map(Request.init),
            response: task.response.map(Response.init),
            error: error.map(ResponseError.init),
            requestBody: originalRequest.httpBody ?? originalRequest.httpBodyStreamData(),
            responseBody: data,
            metrics: metrics,
            label: configuration.label,
            taskDescription: task.taskDescription
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

    // MARK: - Private

    private var tasks: [TaskKey: TaskContext] = [:]

    final class TaskContext {
        let taskId = UUID()
        lazy var data = Data()
        var metrics: NetworkLogger.Metrics?
    }

    private func context(for task: URLSessionTask) -> TaskContext {
        let key = TaskKey(task: task)
        if let context = tasks[key] {
            return context
        }
        let context = TaskContext()
        tasks[key] = context
        return context
    }

    private struct TaskKey: Hashable {
        weak var task: URLSessionTask?

        var id: ObjectIdentifier? { task.map(ObjectIdentifier.init) }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id?.hashValue)
        }

        static func == (lhs: TaskKey, rhs: TaskKey) -> Bool {
            lhs.task != nil && lhs.id == rhs.id
        }
    }
}

private extension URLSessionTask {
    var url: String? {
        originalRequest?.url?.absoluteString
    }
}

private func expandingWildcards(_ pattern: String) -> String {
    let pattern = NSRegularExpression.escapedPattern(for: pattern)
        .replacingOccurrences(of: "\\?", with: ".")
        .replacingOccurrences(of: "\\*", with: "[^\\s]*")
    return "^\(pattern)$"
}
