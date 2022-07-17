// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

public final class NetworkLogger {
    private let store: LoggerStore
    private let lock = NSLock()
    private let isTraceEnabled: Bool
    private let willLogTask: (LoggedNetworkTask) -> LoggedNetworkTask?

    /// - parameter willLogTask: Allows you to filter out sensitive information
    /// or disable logging of certain requests completely. By default, returns
    /// the suggested task without modification.
    public init(store: LoggerStore = .default,
                isTraceEnabled: Bool = false,
                willLogTask: @escaping (LoggedNetworkTask) -> LoggedNetworkTask? = { $0 }) {
        self.store = store
        self.isTraceEnabled = isTraceEnabled
        self.willLogTask = willLogTask
    }

    // MARK: Logging

    /// Logs the task creation (optional).
    public func logTaskCreated(_ task: URLSessionTask) {
        guard let urlRequest = task.originalRequest else { return }
        lock.lock()
        let context = context(for: task)
        lock.unlock()

        trace("Did create task \(urlRequest.httpMethod ?? "–") \(task.url ?? "–")")

        if let request = task.currentRequest ?? context.request {
            store.handle(.networkTaskCreated(LoggerStoreEvent.NetworkTaskCreated(
                taskId: context.taskId,
                createdAt: Date(),
                request: .init(urlRequest: request),
                requestBody: request.httpBody ?? request.httpBodyStreamData(),
                session: LoggerSession.current.id.uuidString
            )))
        }
    }

    /// Logs the task response (optional).
    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        lock.lock()
        let context = self.context(for: dataTask)
        context.response = response
        lock.unlock()

        let response = NetworkLoggerResponse(urlResponse: response)
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

    /// Logs the task completion (required).
    public func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?, session: URLSession? = nil) {
        lock.lock()
        let context = self.context(for: task)
        tasks[ObjectIdentifier(task)] = nil

        guard let request = task.currentRequest ?? context.request else {
            lock.unlock()
            return // This should never happen
        }
        let response = context.response ?? task.response
        let metrics = context.metrics
        let data = context.data
        lock.unlock()

        trace("Did complete with error: \(error?.localizedDescription ?? "-") for \(task.url ?? "null")")

        log(taskId: context.taskId, LoggedNetworkTask(task: task, session: session, request: request, response: response, data: data, error: error, metrics: metrics))
    }

    private func log(taskId: UUID, _ task: LoggedNetworkTask) {
        guard let task = willLogTask(task) else {
            return
        }
        store.storeRequest(taskId: taskId, request: task.request, response: task.response, error: task.error, data: task.data, metrics: task.metrics)
    }

    /// Logs the task metrics (optional).
    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        context(for: task).metrics = NetworkLoggerMetrics(metrics: metrics)
        lock.unlock()
    }

    /// Logs the task metrics (optional).
    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: NetworkLoggerMetrics) {
        lock.lock()
        context(for: task).metrics = metrics
        lock.unlock()
    }

    // MARK: - Filter Out

    public struct LoggedNetworkTask {
        public var task: URLSessionTask
        public var session: URLSession?
        public var request: URLRequest
        public var response: URLResponse?
        public var data: Data?
        public var error: Error?
        public var metrics: NetworkLoggerMetrics?
    }

    // MARK: - Private

    private var tasks: [ObjectIdentifier: TaskContext] = [:]

    final class TaskContext {
        let taskId = UUID()
        var request: URLRequest?
        var response: URLResponse?
        lazy var data = Data()
        var metrics: NetworkLoggerMetrics?
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
        guard isTraceEnabled else { return }
        store.storeMessage(label: "network", level: .trace, message: message, metadata: nil, file: file, function: function, line: line)
    }
}

private extension URLSessionTask {
    var url: String? {
        originalRequest?.url?.absoluteString
    }
}
