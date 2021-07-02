// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation

public final class NetworkLogger {
    private let store: LoggerStore
    private let lock = NSLock()

    public init(store: LoggerStore = .default) {
        self.store = store
    }

    // MARK: Logging

    public func logTaskCreated(_ task: URLSessionTask) {
        guard let urlRequest = task.originalRequest else { return }
        lock.lock()
        defer { lock.unlock() }

        let _ = context(for: task)
        storeMessage(level: .trace, "Send \(urlRequest.httpMethod ?? "–") \(task.url ?? "–")")
    }

    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        lock.lock()
        defer { lock.unlock() }

        let context = self.context(for: dataTask)
        context.response = response

        let response = NetworkLoggerResponse(urlResponse: response)
        let statusCode = response.statusCode

        storeMessage(level: .trace, "Did receive response with status code: \(statusCode.map(descriptionForStatusCode) ?? "–") for \(dataTask.url ?? "null")")
    }

    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        defer { lock.unlock() }

        let context = self.context(for: dataTask)
        context.data.append(data)

        storeMessage(level: .trace, "Did receive data: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) for \(dataTask.url ?? "null")")
    }

    public func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        defer { lock.unlock() }

        store.storeNetworkRequest(for: task, error: error, context: context(for: task))

        tasks[task] = nil
    }

    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.lock()
        defer { lock.unlock() }

        tasks[task]?.metrics = NetworkLoggerMetrics(metrics: metrics)
    }

    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: NetworkLoggerMetrics) {
        lock.lock()
        defer { lock.unlock() }

        tasks[task]?.metrics = metrics
    }

    // MARK: - Private

    private var tasks: [URLSessionTask: TaskContext] = [:]

    final class TaskContext {
        let uuid = UUID()
        var response: URLResponse?
        var metrics: NetworkLoggerMetrics?
        lazy var data = Data()
    }

    private func context(for task: URLSessionTask) -> TaskContext {
        if let context = tasks[task] {
            return context
        }
        let context = TaskContext()
        tasks[task] = context
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

final class NetworkLoggerRequestSummary {
    let request: NetworkLoggerRequest
    let response: NetworkLoggerResponse?
    let error: NetworkLoggerError?
    let requestBody: Data?
    let responseBody: Data?
    let metrics: NetworkLoggerMetrics?

    init(request: NetworkLoggerRequest, response: NetworkLoggerResponse?, error: NetworkLoggerError?, requestBody: Data?, responseBody: Data?, metrics: NetworkLoggerMetrics?) {
        self.request = request
        self.response = response
        self.error = error
        self.requestBody = requestBody
        self.responseBody = responseBody
        self.metrics = metrics
    }
}
