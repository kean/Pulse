// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A wrapper on top of ``LoggerStore`` that simplifies logging of network requests.
///
/// - note: ``NetworkLogger`` is used internally by ``URLSessionProxyDelegate`` and
/// should generally not be used directly.
public final class NetworkLogger: Sendable {
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

        /// Store logs only for the included hosts.
        ///
        /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
        /// when ``isRegexEnabled`` option is enabled.
        public var includedHosts: Set<String> = []

        /// Store logs only for the included URLs.
        ///
        /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
        /// when ``isRegexEnabled`` option is enabled.
        public var includedURLs: Set<String> = []

        /// Exclude the given hosts from the logs.
        ///
        /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
        /// when ``isRegexEnabled`` option is enabled.
        public var excludedHosts: Set<String> = []

        /// Exclude the given URLs from the logs.
        ///
        /// - note: Supports wildcards, e.g. `*.example.com`, and full regex
        /// when ``isRegexEnabled`` option is enabled.
        public var excludedURLs: Set<String> = []

        /// Redact the given HTTP headers from the logged requests and responses.
        ///
        /// - note: Supports wildcards, e.g. `X-*`, and full regex
        /// when ``isRegexEnabled`` option is enabled.
        public var sensitiveHeaders: Set<String> = []

        /// Redact the given query items from the URLs.
        ///
        /// - note: Supports only plain strings. Case-sensitive.
        public var sensitiveQueryItems: Set<String> = []

        /// Redact the given JSON fields from the logged requests and responses bodies.
        ///
        /// - note: Supports only plain strings. Case-sensitive.
        public var sensitiveDataFields: Set<String> = []

        /// If enabled, processes `include` and `exclude` patterns using regex.
        /// By default, patterns support only basic wildcard syntax: `*.example.com`.
        public var isRegexEnabled = false

        /// Gets called when the logger receives an event. You can use it to
        /// modify the event before it is stored in order, for example, filter
        /// out some sensitive information. If you return `nil`, the event
        /// is ignored completely.
        public var willHandleEvent: @Sendable (LoggerStore.Event) -> LoggerStore.Event? = { $0 }

        /// Initializes the default configuration.
        public init() {}
    }

    private let imp: _NetworkLogger

    /// Initializes the network logger.
    ///
    /// - parameters:
    ///   - store: The target store for network requests.
    ///   - configuration: The store configuration.
    public init(store: LoggerStore = .shared, configuration: Configuration = .init()) {
        self.imp = _NetworkLogger(store: store, configuration: configuration)
    }

    /// Initializes and configures the network logger.
    public convenience init(store: LoggerStore = .shared, _ configure: (inout Configuration) -> Void) {
        var configuration = Configuration()
        configure(&configuration)
        self.init(store: store, configuration: configuration)
    }

    public func logTaskCreated(_ task: URLSessionTask) {
        let date = Date()
        Task { @PulseActor in
            imp.logTaskCreated(task, createdAt: date)
        }
    }

    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        Task { @PulseActor in
            imp.logDataTask(dataTask, didReceive: data)
        }
    }

    public func logTask(_ task: URLSessionTask, didUpdateProgress progress: (completed: Int64, total: Int64)) {
        Task { @PulseActor in
            imp.logTask(task, didUpdateProgress: progress)
        }
    }

    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        Task { @PulseActor in
            imp.logTask(task, didFinishCollecting: metrics)
        }
    }


    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: NetworkLogger.Metrics) {
        Task { @PulseActor in
            imp.logTask(task, didFinishCollecting: metrics)
        }
    }

    public func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        let date = Date()
        Task { @PulseActor in
            imp.logTask(task, didCompleteWithError: error, createdAt: date)
        }
    }

    public func logTask(_ task: URLSessionTask, didFinishDecodingWithError error: Error?) {
        let date = Date()
        Task { @PulseActor in
            imp.logTask(task, didFinishDecodingWithError: error, createdAt: date)
        }
    }
}

@PulseActor
private class _NetworkLogger: @unchecked Sendable {
    private let configuration: NetworkLogger.Configuration
    private let store: LoggerStore

    private let includedHosts: [Regex]
    private let includedURLs: [Regex]
    private let excludedHosts: [Regex]
    private let excludedURLs: [Regex]

    private let sensitiveHeaders: [Regex]
    private let sensitiveQueryItems: Set<String>
    private let sensitiveDataFields: Set<String>

    private let isFilteringNeeded: Bool

    /// Initializes the network logger.
    ///
    /// - parameters:
    ///   - store: The target store for network requests.
    ///   - configuration: The store configuration.
    nonisolated init(store: LoggerStore = .shared, configuration: NetworkLogger.Configuration = .init()) {
        self.store = store
        self.configuration = configuration

        func process(_ pattern: String) -> Regex? {
            process(pattern, options: [])
        }

        func process(_ pattern: String, options: [Regex.Options]) -> Regex? {
            do {
                let pattern = configuration.isRegexEnabled ? pattern : expandingWildcards(pattern)
                return try Regex(pattern)
            } catch {
                debugPrint("Failed to parse pattern: \(pattern) \(error)")
                return nil
            }
        }

        self.includedHosts = configuration.includedHosts.compactMap(process)
        self.includedURLs = configuration.includedURLs.compactMap(process)
        self.excludedHosts = configuration.excludedHosts.compactMap(process)
        self.excludedURLs = configuration.excludedURLs.compactMap(process)
        self.sensitiveHeaders = configuration.sensitiveHeaders.compactMap {
            process($0, options: [.caseInsensitive])
        }
        self.sensitiveQueryItems = configuration.sensitiveQueryItems
        self.sensitiveDataFields = configuration.sensitiveDataFields

        self.isFilteringNeeded = !includedHosts.isEmpty || !excludedHosts.isEmpty || !includedURLs.isEmpty || !excludedURLs.isEmpty
    }

    // MARK: Logging

    /// Logs the task creation (optional).
    func logTaskCreated(_ task: URLSessionTask, createdAt: Date) {
        guard tasks[TaskKey(task: task)] == nil else {
            return // Already registered
        }
        let context = context(for: task)

        guard let originalRequest = task.originalRequest else { return }
        send(.networkTaskCreated(LoggerStore.Event.NetworkTaskCreated(
            taskId: context.taskId,
            taskType: NetworkLogger.TaskType(task: task),
            createdAt: createdAt,
            originalRequest: .init(originalRequest),
            currentRequest: task.currentRequest.map(NetworkLogger.Request.init),
            label: configuration.label,
            taskDescription: task.taskDescription
        )))
    }

    /// Logs the task data that gets appended to the previously received chunks (required).
    func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        let context = self.context(for: dataTask)
        context.data.append(data)
    }

    func logTask(_ task: URLSessionTask, didUpdateProgress progress: (completed: Int64, total: Int64)) {
        let context = self.context(for: task)

        send(.networkTaskProgressUpdated(.init(
            taskId: context.taskId,
            url: task.originalRequest?.url,
            completedUnitCount: progress.completed,
            totalUnitCount: progress.total
        )))
    }

    /// Logs the task completion (required).
    func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?, createdAt: Date) {
        guard error != nil || !configuration.isWaitingForDecoding else { return }
        _logTask(task, didCompleteWithError: error, createdAt: createdAt)
    }

    /// Logs the task metrics (optional).
    func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        context(for: task).metrics = NetworkLogger.Metrics(metrics: metrics)
    }

    /// Logs the task metrics (optional).
    func logTask(_ task: URLSessionTask, didFinishCollecting metrics: NetworkLogger.Metrics) {
        context(for: task).metrics = metrics
    }

    func logTask(_ task: URLSessionTask, didFinishDecodingWithError error: Error?, createdAt: Date) {
        _logTask(task, didCompleteWithError: error, createdAt: createdAt)
    }

    private func _logTask(_ task: URLSessionTask, didCompleteWithError error: Error?, createdAt: Date) {
        let context = self.context(for: task)
        tasks[TaskKey(task: task)] = nil

        guard let originalRequest = task.originalRequest else {
            return // This should never happen
        }

        let metrics = context.metrics
        let data = context.data

        send(.networkTaskCompleted(.init(
            taskId: context.taskId,
            taskType: NetworkLogger.TaskType(task: task),
            createdAt: createdAt,
            originalRequest: NetworkLogger.Request(originalRequest),
            currentRequest: task.currentRequest.map(NetworkLogger.Request.init),
            response: task.response.map(NetworkLogger.Response.init),
            error: error.map(NetworkLogger.ResponseError.init),
            requestBody: originalRequest.httpBody ?? originalRequest.httpBodyStreamData(),
            responseBody: data,
            metrics: metrics,
            label: configuration.label,
            taskDescription: task.taskDescription
        )))
    }

    private func send(_ event: LoggerStore.Event) {
        guard !isFilteringNeeded || filter(event) else {
            return
        }
        guard let event = configuration.willHandleEvent(preprocess(event)) else {
            return
        }
        store.handle(event)
    }

    /// Check if the events can be stored (included and not excluded).
    private func filter(_ event: LoggerStore.Event) -> Bool {
        guard let url = event.url else {
            return false // Should never happen
        }
        var host = url.host ?? ""
        if url.scheme == nil, let url = URL(string: "https://" + url.absoluteString) {
            host = url.host ?? "" // URL(string: "example.com")?.host with not scheme returns host: ""
        }
        let absoluteString = url.absoluteString
        if !includedHosts.isEmpty || !includedURLs.isEmpty {
            guard includedHosts.contains(where: { $0.isMatch(host) }) ||
                    includedURLs.contains(where: { $0.isMatch(absoluteString) }) else {
                return false
            }
        }
        if !excludedHosts.isEmpty && excludedHosts.contains(where: { $0.isMatch(host) }) {
            return false
        }
        if !excludedURLs.isEmpty && excludedURLs.contains(where: { $0.isMatch(absoluteString) }) {
            return false
        }
        return true
    }

    private func preprocess(_ event: LoggerStore.Event) -> LoggerStore.Event {
        event
            .redactingSensitiveHeaders(sensitiveHeaders)
            .redactingSensitiveQueryItems(sensitiveQueryItems)
            .redactingSensitiveResponseDataFields(sensitiveDataFields)
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
