// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import Logging

public final class NetworkLogger: NSObject {
    private let logger: Logger
    private let blobStore: BlobStore
    private let queue = DispatchQueue(label: "com.github.kean.pulse.network-logger", target: .global(qos: .utility))

    /// - parameter logger: By default, create a Logger with "network" label and
    /// `logLevel` set `.trace`. Assumes that the `LoggingSystem.bootstrap` is used.
    /// - parameter blobs: By default, uses `BlobStore.default`. If you want to use
    /// a custom blob store, make sure to pass the same store to `ConsoleView` when
    /// instantiating it.
    public init(logger: Logger = NetworkLogger.makeDefaultLogger(),
                blobStore: BlobStore = .default) {
        self.logger = logger
        self.blobStore = blobStore
    }

    public static func makeDefaultLogger() -> Logger {
        var logger = Logger(label: "network")
        logger.logLevel = .trace
        return logger
    }

    // MARK: Logging

    public func logTaskCreated(_ task: URLSessionTask) {
        let date = Date()
        queue.async { self._logTaskCreated(task, date: date) }
    }

    private func _logTaskCreated(_ task: URLSessionTask, date: Date) {
        guard let urlRequest = task.originalRequest else { return }

        let context = self.context(for: task)

        let request = NetworkLoggerRequest(urlRequest: urlRequest)
        let event = NetworkLoggerEvent.TaskDidStart(request: request)

        logger.log(
            level: .trace,
            "Did start request \(task.originalRequest?.url?.absoluteString ?? "null")",
            metadata: makeMetadata(context, task, .taskDidStart, event, date)
        )
    }

    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse) {
        let date = Date()
        queue.async { self._logDataTask(dataTask, didReceive: response, date: date) }
    }

    private func _logDataTask(_ dataTask: URLSessionDataTask, didReceive response: URLResponse, date: Date) {
        let context = self.context(for: dataTask)
        context.response = response

        let response = NetworkLoggerResponse(urlResponse: response)
        let event = NetworkLoggerEvent.DataTaskDidReceieveResponse(response: response)
        let statusCode = response.statusCode

        logger.log(
            level: .trace,
            "Did receive response with status code: \(statusCode.map(descriptionForStatusCode) ?? "–") for \(dataTask.url ?? "null")",
            metadata: makeMetadata(context, dataTask, .dataTaskDidReceieveResponse, event, date)
        )
    }

    public func logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data) {
        let date = Date()
        queue.async { self._logDataTask(dataTask, didReceive: data, date: date) }
    }

    private func _logDataTask(_ dataTask: URLSessionDataTask, didReceive data: Data, date: Date) {
        let context = self.context(for: dataTask)
        context.data.append(data)

        let event = NetworkLoggerEvent.DataTaskDidReceiveData(dataCount: data.count)

        logger.log(
            level: .trace,
            "Did receive data: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)) for \(dataTask.url ?? "null")",
            metadata: makeMetadata(context, dataTask, .dataTaskDidReceiveData, event, date)
        )
    }

    public func logTask(_ task: URLSessionTask, didCompleteWithError error: Error?) {
        let date = Date()
        queue.async { self._logTask(task, didCompleteWithError: error, date: date) }
    }

    private func _logTask(_ task: URLSessionTask, didCompleteWithError error: Error?, date: Date) {
        guard let urlRequest = task.originalRequest else { return }
        let context = self.context(for: task)

        let event = NetworkLoggerEvent.TaskDidComplete(
            request: NetworkLoggerRequest(urlRequest: urlRequest),
            response: context.response.map(NetworkLoggerResponse.init),
            error: error.map(NetworkLoggerError.init),
            requestBodyKey: blobStore.storeData(urlRequest.httpBody),
            responseBodyKey: blobStore.storeData(context.data),
            metrics: context.metrics
        )

        let level: Logger.Level
        let message: String
        if let error = error {
            level = .error
            message = "🌐 \(urlRequest.httpMethod ?? "–") \(task.url ?? "–") failed. \(error.localizedDescription)"
        } else {
            let statusCode = (context.response as? HTTPURLResponse)?.statusCode
            if let statusCode = statusCode, !(200..<400).contains(statusCode) {
                level = .error
            } else {
                level = .debug
            }
            message = "🌐 \(statusCode.map(descriptionForStatusCode) ?? "–") \(urlRequest.httpMethod ?? "–") \(task.url ?? "–")"
        }

        logger.log(level: level, .init(stringLiteral: message), metadata: makeMetadata(context, task, .taskDidComplete, event, date))

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

    private func makeMetadata<T: Encodable>(_ context: TaskContext, _ task: URLSessionTask, _ eventType: NetworkLoggerEventType, _ payload: T, _ date: Date) -> Logger.Metadata {
        [
            NetworkLoggerMetadataKey.taskId.rawValue: .string(context.uuid.uuidString),
            NetworkLoggerMetadataKey.eventType.rawValue: .string(eventType.rawValue),
            NetworkLoggerMetadataKey.taskType.rawValue: .string(NetworkLoggerTaskType(task: task).rawValue),
            NetworkLoggerMetadataKey.payload.rawValue: .string(encode(payload) ?? ""),
            NetworkLoggerMetadataKey.createdAt: .stringConvertible(date)
        ]
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
