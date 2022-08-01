// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

public final class NetworkLogger: @unchecked Sendable {
    private let store: LoggerStore
    private let lock = NSLock()
    private let configuration: Configuration

    /// The logger configuration.
    public struct Configuration: Sendable {
        /// Add log messages with ``LoggerStore/Level/trace`` level for all
        /// logged `URLSession` events.
        public var isTraceEnabled: Bool
        /// If enabled, the requests are not marked as completed until the decoding
        /// is done (see ``NetworkLogger/logTask(_:didFinishDecoding:)-347rd``).
        /// If the request itself fails, the task completes immediately.
        public var isWaitingForDecoding: Bool

        /// Gets called when the logger receives an event. You can use it to
        /// modify the event before it is stored in order, for example, filter
        /// out some sensitive information. If you return `nil`, the event
        /// is ignored completely.
        public var willHandleEvent: @Sendable (LoggerStore.Event) -> LoggerStore.Event? = { $0 }

        /// Initializes the configuration.
        public init(isTraceEnabled: Bool = false, isWaitingForDecoding: Bool = false) {
            self.isTraceEnabled = isTraceEnabled
            self.isWaitingForDecoding = isWaitingForDecoding
        }
    }

    /// Initializers the network logger.
    ///
    /// - parameters:
    ///   - isTraceEnabled: Add log messages with ``LoggerStore/Level/trace`` level
    ///   for all logged `URLSession` events.
    ///   - isWaitingForDecoding: Don't mark the request completed until the
    ///   decoding is done. If the request itself fails, the task completes
    ///   immediately.
    ///   - willLogTask: Allows you to filter out sensitive information
    /// or disable logging of certain requests completely. By default, returns
    /// the suggested task without modification.
    public init(store: LoggerStore = .shared,
                configuration: Configuration = .init()) {
        self.store = store
        self.configuration = configuration
    }

    // MARK: Logging

    /// Logs the task creation (optional).
    public func logTaskCreated(_ task: URLSessionTask) {
        guard let urlRequest = task.originalRequest else { return }
        lock.lock()
        let context = context(for: task)
        lock.unlock()

        trace("Did create task \(urlRequest.httpMethod ?? "–") \(task.url ?? "–")")

        if let originalRequest = task.originalRequest ?? context.request {
            send(.networkTaskCreated(LoggerStore.Event.NetworkTaskCreated(
                taskId: context.taskId,
                taskType: NetworkLogger.TaskType(task: task),
                createdAt: Date(),
                originalRequest: .init(originalRequest),
                currentRequest: task.currentRequest.map(Request.init),
                requestBody: originalRequest.httpBody ?? originalRequest.httpBodyStreamData(),
                session: LoggerStore.Session.current.id.uuidString
            )))
        }
    }

    /// Logs the task response (optional).
    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        lock.lock()
        let context = self.context(for: dataTask)
        context.response = response
        lock.unlock()

        let response = Response(response)
        let statusCode = response.statusCode

        trace("Did receive response with status code: \(statusCode.map(descriptionForStatusCode) ?? "–") for \(dataTask.url ?? "null")")
    }

    /// Logs the task data that gets appended to the previously received chunks (required).
    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        let context = self.context(for: dataTask)
        context.data.append(data)
        lock.unlock()

        trace("Did receive data: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) for \(dataTask.url ?? "null")")
    }

    public func logTask(_ task: URLSessionTask, didUpdateProgress progress: (completed: Int64, total: Int64)) {
        lock.lock()
        let context = self.context(for: task)
        lock.unlock()

        send(.networkTaskProgressUpdated(.init(
            taskId: context.taskId,
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

    /// Notifies the logger the decoding for the given task is completed.
    public func logTask<T>(_ task: URLSessionTask, didFinishDecoding result: Result<T, Error>) {
        _logTask(task, didFinishDecoding: result)
    }

    public func logTask(_ task: URLSessionTask, didFinishDecoding result: Result<Void, Error>) {
        _logTask(task, didFinishDecoding: result)
    }

    private func _logTask<T>(_ task: URLSessionTask, didFinishDecoding result: Result<T, Error>) {
        var error: Error?
        if case .failure(let failure) = result {
            error = failure
        }
        _logTask(task, didCompleteWithError: error)

        trace("Did complete decoding with result: \(result) for \(task.url ?? "null")")
    }

    private func _logTask(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let context = self.context(for: task)
        tasks[ObjectIdentifier(task)] = nil

        guard let originalRequest = task.originalRequest ?? context.request else {
            lock.unlock()
            return // This should never happen
        }
        let response = context.response ?? task.response
        let metrics = context.metrics
        let data = context.data
        lock.unlock()

        send(.networkTaskCompleted(.init(
            taskId: context.taskId,
            taskType: NetworkLogger.TaskType(task: task),
            createdAt: Date(),
            originalRequest: Request(originalRequest),
            currentRequest: task.currentRequest.map(Request.init),
            response: response.map(Response.init),
            error: error.map(ResponseError.init),
            requestBody: originalRequest.httpBody ?? originalRequest.httpBodyStreamData(),
            responseBody: data,
            metrics: metrics,
            session: LoggerStore.Session.current.id.uuidString
        )))

        trace("Did complete with error: \(error?.localizedDescription ?? "-") for \(task.url ?? "null")")
    }

    private func send(_ event: LoggerStore.Event) {
        guard let event = configuration.willHandleEvent(event) else {
            return
        }
        store.handle(event)
    }

    // MARK: - Private

    private var tasks: [ObjectIdentifier: TaskContext] = [:]

    final class TaskContext {
        let taskId = UUID()
        var request: URLRequest?
        var response: URLResponse?
        lazy var data = Data()
        var metrics: NetworkLogger.Metrics?
    }

    private func context(for task: URLSessionTask) -> TaskContext {
        func getContext() -> TaskContext {
            if let context = tasks[ObjectIdentifier(task)] {
                return context
            }
            let context = TaskContext()
            tasks[ObjectIdentifier(task)] = context
            return context
        }
        let context = getContext()
        if let request = task.originalRequest {
            context.request = request
        }
        return context
    }

    private func trace(_ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        guard configuration.isTraceEnabled else { return }
        store.storeMessage(label: "network", level: .trace, message: message, metadata: nil, file: file, function: function, line: line)
    }
}

private extension URLSessionTask {
    var url: String? {
        originalRequest?.url?.absoluteString
    }
}
