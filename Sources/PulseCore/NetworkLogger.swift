// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation

public final class NetworkLogger {
    private let store: LoggerStore
    private let lock = NSLock()
    
    private let willLogTask: (LoggedNetworkTask) -> LoggedNetworkTask?

    /// - parameter willLogTask: Allows you to filter out sensitive information
    /// or disable logging of certain requests completely. By default, returns
    /// the suggested task without modification.
    public init(store: LoggerStore = .default,
                willLogTask: @escaping (LoggedNetworkTask) -> LoggedNetworkTask? = { $0 }) {
        self.store = store
        self.willLogTask = willLogTask
    }

    // MARK: Logging

    /// Logs the task creation (optional).
    public func logTaskCreated(_ task: URLSessionTask) {
        guard let urlRequest = task.originalRequest else { return }
        lock.lock()
        defer { lock.unlock() }

        let _ = context(for: task)
        storeMessage(level: .trace, "Send \(urlRequest.httpMethod ?? "–") \(task.url ?? "–")")
    }

    /// Logs the task response (optional).
    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        lock.lock()
        defer { lock.unlock() }

        let context = self.context(for: dataTask)
        context.response = response

        let response = NetworkLoggerResponse(urlResponse: response)
        let statusCode = response.statusCode

        storeMessage(level: .trace, "Did receive response with status code: \(statusCode.map(descriptionForStatusCode) ?? "–") for \(dataTask.url ?? "null")")
    }

    /// Logs the task data that gets appended to the previously received chunks (required).
    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        defer { lock.unlock() }

        let context = self.context(for: dataTask)
        context.data.append(data)

        storeMessage(level: .trace, "Did receive data: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) for \(dataTask.url ?? "null")")
    }

    /// Logs the task completion (required).
    public func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?, session: URLSession? = nil) {
        lock.lock()
        defer { lock.unlock() }
        
        let context = self.context(for: task)
        tasks[ObjectIdentifier(task)] = nil
        
        guard let request = task.currentRequest ?? context.request else {
            return // This should never happen
        }
        let response = context.response ?? task.response
        
        log(LoggedNetworkTask(task: task, session: session, request: request, response: response, data: context.data, error: error, metrics: context.metrics))
    }
    
    private func log(_ task: LoggedNetworkTask) {
        guard let task = willLogTask(task) else {
            return
        }
        store.storeRequest(task.request, response: task.response, error: task.error, data: task.data, metrics: task.metrics, session: task.session)
    }

    /// Logs the task metrics (optional).
    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        defer { lock.unlock() }

        context(for: task).metrics = NetworkLoggerMetrics(metrics: metrics)
    }

    /// Logs the task metrics (optional).
    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: NetworkLoggerMetrics) {
        lock.lock()
        defer { lock.unlock() }

        context(for: task).metrics = metrics
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

    private func storeMessage(level: LoggerStore.Level, _ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        store.storeMessage(label: "network", level: level, message: message, metadata: nil, file: file, function: function, line: line)
    }
}

private extension URLSessionTask {
    var url: String? {
        originalRequest?.url?.absoluteString
    }
}
