// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

/// A wrapper on top of ``LoggerStore`` that simplifies logging of network requests.
///
/// - note: ``NetworkLogger`` is used internally by ``URLSessionProxyDelegate`` and
/// should generally not be used directly.
public final class NetworkLogger: @unchecked Sendable {
    private let store: LoggerStore
    private let lock = NSLock()
    private let configuration: Configuration

    /// The logger configuration.
    public struct Configuration: Sendable {
        /// If enabled, the requests are not marked as completed until the decoding
        /// is done (see ``NetworkLogger/logTask(_:didFinishDecodingWithError:)``.
        /// If the request itself fails, the task completes immediately.
        public var isWaitingForDecoding: Bool

        /// Gets called when the logger receives an event. You can use it to
        /// modify the event before it is stored in order, for example, filter
        /// out some sensitive information. If you return `nil`, the event
        /// is ignored completely.
        public var willHandleEvent: @Sendable (LoggerStore.Event) -> LoggerStore.Event? = { $0 }

        /// Initializes the configuration.
        public init(isWaitingForDecoding: Bool = false) {
            self.isWaitingForDecoding = isWaitingForDecoding
        }
    }

    /// Initializers the network logger.
    ///
    /// - parameters:
    ///   - store: The target store for network requests.
    ///   - configuration: The store configuration.
    public init(store: LoggerStore = .shared, configuration: Configuration = .init()) {
        self.store = store
        self.configuration = configuration
    }

    // MARK: Logging

    /// Logs the task creation (optional).
    public func logTaskCreated(_ task: URLSessionTask) {
        lock.lock()
        let context = context(for: task)
        lock.unlock()

        guard let originalRequest = task.originalRequest ?? context.request else { return }
        send(.networkTaskCreated(LoggerStore.Event.NetworkTaskCreated(
            taskId: context.taskId,
            taskType: NetworkLogger.TaskType(task: task),
            createdAt: Date(),
            originalRequest: .init(originalRequest),
            currentRequest: task.currentRequest.map(Request.init),
            session: LoggerStore.Session.current.id
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
        tasks[ObjectIdentifier(task)] = nil

        guard let originalRequest = task.originalRequest ?? context.request else {
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
            session: LoggerStore.Session.current.id
        )))
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
}

private extension URLSessionTask {
    var url: String? {
        originalRequest?.url?.absoluteString
    }
}
