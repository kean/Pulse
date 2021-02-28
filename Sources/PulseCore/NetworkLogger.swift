// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation

public final class NetworkLogger: NSObject {
    private let store: LoggerMessageStore
    private let blobStore: BlobStore
    private let queue = DispatchQueue(label: "com.github.kean.pulse.network-logger", target: .global(qos: .utility))

    public init(store: LoggerMessageStore = .default, blobStore: BlobStore = .default) {
        self.store = store
        self.blobStore = blobStore
    }
    // MARK: Logging

    public func logTaskCreated(_ task: URLSessionTask) {
        let date = Date()
        queue.async { self._logTaskCreated(task, date: date) }
    }

    private func _logTaskCreated(_ task: URLSessionTask, date: Date) {
        guard let urlRequest = task.originalRequest else { return }

        let _ = self.context(for: task)
        storeMessage(level: .trace, "Send \(urlRequest.httpMethod ?? "–") \(task.originalRequest?.url?.absoluteString ?? "–")")
    }

    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        let date = Date()
        queue.async { self._logDataTask(dataTask, didReceive: response, date: date) }
    }

    private func _logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse, date: Date) {
        let context = self.context(for: dataTask)
        context.response = response

        let response = NetworkLoggerResponse(urlResponse: response)
        let statusCode = response.statusCode

        storeMessage(level: .trace, "Did receive response with status code: \(statusCode.map(descriptionForStatusCode) ?? "–") for \(dataTask.url ?? "null")")
    }

    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        let date = Date()
        queue.async { self._logDataTask(dataTask, didReceive: data, date: date) }
    }

    private func _logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data, date: Date) {
        let context = self.context(for: dataTask)
        context.data.append(data)

        storeMessage(level: .trace, "Did receive data: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) for \(dataTask.url ?? "null")")
    }

    public func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        let date = Date()
        queue.async { self._logTask(task, didCompleteWithError: error, date: date) }
    }

    private func _logTask(_ task: URLSessionTask, didCompleteWithError error: Error?, date: Date) {
        guard let urlRequest = task.originalRequest else { return }
        let context = self.context(for: task)

        let event = NetworkLoggerRequestSummary(
            request: NetworkLoggerRequest(urlRequest: urlRequest),
            response: context.response.map(NetworkLoggerResponse.init),
            error: error.map(NetworkLoggerError.init),
            requestBodyKey: blobStore.storeData(urlRequest.httpBody),
            responseBodyKey: blobStore.storeData(context.data),
            metrics: context.metrics
        )

        let level: LoggerMessageStore.Level
        var message = "\(urlRequest.httpMethod ?? "–") \(task.url ?? "–")"
        if let error = error {
            level = .error
            message += " \((error as NSError).code) \(error.localizedDescription)"
        } else {
            let statusCode = (context.response as? HTTPURLResponse)?.statusCode
            if let statusCode = statusCode, !(200..<400).contains(statusCode) {
                level = .error
            } else {
                level = .debug
            }
            message += " \(statusCode.map(descriptionForStatusCode) ?? "–")"
        }

        store.storeNetworkRequest(event, createdAt: date, level: level, message: message)

        tasks[task] = nil
    }

    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        queue.async { self.tasks[task]?.metrics = NetworkLoggerMetrics(metrics: metrics) }
    }

    public func logTask(_ task: URLSessionTask, didFinishCollecting metrics: NetworkLoggerMetrics) {
        queue.async { self.tasks[task]?.metrics = metrics }
    }

    // MARK: - Private

    private var tasks: [URLSessionTask: TaskContext] = [:]

    private final class TaskContext {
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

    private func storeMessage(level: LoggerMessageStore.Level, _ message: String, file: String = #file, function: String = #function, line: UInt = #line) {
        store.storeMessage(label: "network", level: level, message: message, metadata: nil, file: file, function: function, line: line)
    }
}

private extension URLSessionTask {
    var url: String? {
        originalRequest?.url?.absoluteString
    }
}

private func encode<T: Encodable>(_ value: T) -> String? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
}

private func descriptionForStatusCode(_ statusCode: Int) -> String {
    switch statusCode {
    case 200: return "200 (OK)"
    default: return "\(statusCode) (\( HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized))"
    }
}

struct NetworkLoggerRequestSummary {
    let request: NetworkLoggerRequest
    let response: NetworkLoggerResponse?
    let error: NetworkLoggerError?
    let requestBodyKey: String?
    let responseBodyKey: String?
    let metrics: NetworkLoggerMetrics?
}
