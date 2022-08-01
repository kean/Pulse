// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

#if DEBUG || PULSE_DEMO

extension LoggerStore {
    static let mock: LoggerStore = {
        let store: LoggerStore = MockStoreConfiguration.isUsingDefaultStore ? .shared : makeMockStore()

        if MockStoreConfiguration.isDelayingLogs {
            func populate() {
                asyncPopulateStore(store)
                if !MockStoreConfiguration.isIndefinite {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(14)) {
                        populate()
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
                populate()
            }
        } else {
            _syncPopulateStore(store)
        }

        return store
    }()

    // Store with
    static let preview = makeMockStore()
}

private let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("pulseui-demo")

private let cleanup: Void = {
    try? FileManager.default.removeItem(at: rootURL)
    try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
}()

private func makeMockStore() -> LoggerStore {
    _ = cleanup

    let storeURL = rootURL.appendingPathComponent("\(UUID().uuidString).pulse")
    return try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous])
}

private struct Logger {
    let label: String
    let store: LoggerStore

    func log(level: LoggerStore.Level, _ message: String, metadata: LoggerStore.Metadata? = nil) {
        self.store.storeMessage(label: label, level: level, message: message, metadata: metadata, file: "", function: "", line: 0)
    }
}

private var isFirstLog = true

private func asyncPopulateStore(_ store: LoggerStore) {
    Task { @MainActor in
        await _asyncPopulateStore(store)
    }
}

private func _asyncPopulateStore(_ store: LoggerStore) async {
    @Sendable func logger(named: String) -> Logger {
        Logger(label: named, store: store)
    }

    let networkLogger = NetworkLogger(store: store, isWaitingForDecoding: true)

    let urlSession = URLSession(configuration: .default)

    if isFirstLog {
        isFirstLog = false
        logger(named: "application")
            .log(level: .info, "UIApplication.didFinishLaunching", metadata: [
                "custom-metadata-key": .string("value")
            ])

        logger(named: "application")
            .log(level: .info, "UIApplication.willEnterForeground")

        await Task.sleep(milliseconds: 300)

        logger(named: "auth")
            .log(level: .trace, "Instantiated Session")

        logger(named: "auth")
            .log(level: .trace, "Instantiated the new login request")

        await Task.sleep(milliseconds: 800)

        logger(named: "application")
                .log(level: .debug, "Will navigate to Dashboard")
    }

    for task in MockTask.allTasks {
        _logTask(task, urlSession: urlSession, logger: networkLogger, delay: task.delay)
    }

    let stackTrace = """
        Replace this implementation with code to handle the error appropriately. fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

        2015-12-08 15:04:03.888 Conversion[76776:4410388] call stack:
        (
            0   Conversion                          0x000694b5 -[ViewController viewDidLoad] + 128
            1   UIKit                               0x27259f55 <redacted> + 1028
            ...
            9   UIKit                               0x274f67a7 <redacted> + 134
            10  FrontBoardServices                  0x2b358ca5 <redacted> + 232
            11  FrontBoardServices                  0x2b358f91 <redacted> + 44
            12  CoreFoundation                      0x230e87c7 <redacted> + 14
            ...
            16  CoreFoundation                      0x23038ecd CFRunLoopRunInMode + 108
            17  UIKit                               0x272c7607 <redacted> + 526
            18  UIKit                               0x272c22dd UIApplicationMain + 144
            19  Conversion                          0x000767b5 main + 108
            20  libdyld.dylib                       0x34f34873 <redacted> + 2
        )
        """

    logger(named: "auth")
        .log(level: .warning, .init(stringLiteral: stackTrace))

    await Task.sleep(milliseconds: 10000)

    logger(named: "default")
        .log(level: .critical, "💥 0xDEADBEEF")
}

private func _syncPopulateStore(_ store: LoggerStore) {
    func logger(named: String) -> Logger {
        Logger(label: named, store: store)
    }

    let networkLogger = NetworkLogger(store: store, isWaitingForDecoding: true)

    let urlSession = URLSession(configuration: .default)

    if isFirstLog {
        isFirstLog = false
        logger(named: "application")
            .log(level: .info, "UIApplication.didFinishLaunching", metadata: [
                "custom-metadata-key": .string("value")
            ])

        logger(named: "application")
            .log(level: .info, "UIApplication.willEnterForeground")

        logger(named: "auth")
            .log(level: .trace, "Instantiated Session")

        logger(named: "auth")
            .log(level: .trace, "Instantiated the new login request")

        logger(named: "application")
                .log(level: .debug, "Will navigate to Dashboard")
    }

    for task in MockTask.allTasks {
        _logTask(task, urlSession: urlSession, logger: networkLogger)
    }

    let stackTrace = """
        Replace this implementation with code to handle the error appropriately. fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

        2015-12-08 15:04:03.888 Conversion[76776:4410388] call stack:
        (
            0   Conversion                          0x000694b5 -[ViewController viewDidLoad] + 128
            1   UIKit                               0x27259f55 <redacted> + 1028
            ...
            9   UIKit                               0x274f67a7 <redacted> + 134
            10  FrontBoardServices                  0x2b358ca5 <redacted> + 232
            11  FrontBoardServices                  0x2b358f91 <redacted> + 44
            12  CoreFoundation                      0x230e87c7 <redacted> + 14
            ...
            16  CoreFoundation                      0x23038ecd CFRunLoopRunInMode + 108
            17  UIKit                               0x272c7607 <redacted> + 526
            18  UIKit                               0x272c22dd UIApplicationMain + 144
            19  Conversion                          0x000767b5 main + 108
            20  libdyld.dylib                       0x34f34873 <redacted> + 2
        )
        """

    logger(named: "auth")
        .log(level: .warning, .init(stringLiteral: stackTrace))

    logger(named: "default")
        .log(level: .critical, "💥 0xDEADBEEF")
}

private func _logTask(_ mockTask: MockTask, urlSession: URLSession, logger: NetworkLogger, delay: TimeInterval) {
    let task = makeSessionTask(for: mockTask, urlSession: urlSession)

    @Sendable func logTask() async {
        await Task.sleep(milliseconds: Int(1000 * delay))
        let startDate = Date()
        logger.logTaskCreated(task)
        switch mockTask.kind {
        case .download(let size), .upload(let size):
            await Task.sleep(milliseconds: 300)
            var remaining = size
            let chunk: Int64 = 1024 * (size > 10000000 ? 1024 : 512)
            while remaining > 0 {
                await Task.sleep(milliseconds: 200)
                remaining -= chunk
                logger.logTask(task, didUpdateProgress: (completed: size - remaining, total: size))
            }
        case .data:
            await Task.sleep(milliseconds: .random(in: 500...2000))
        }
        if let dataTask = task as? URLSessionDataTask {
            logger.logDataTask(dataTask, didReceive: mockTask.response)
            logger.logDataTask(dataTask, didReceive: mockTask.responseBody)
        }
        
        let taskInterval = DateInterval(start: startDate, duration: mockTask.duration)
        let metrics = makeMetrics(for: mockTask, taskInterval: taskInterval)
        logger.logTask(task, didFinishCollecting: metrics)
        logger.logTask(task, didCompleteWithError: nil)

        await Task.sleep(milliseconds: 50)

        if let error = mockTask.decodingError {
            logger.logTask(task, didFinishDecoding: .failure(error))
        } else {
            logger.logTask(task, didFinishDecoding: .success("success"))
        }
    }

    Task.detached {
        await logTask()
    }
}

private func _logTask(_ mockTask: MockTask, urlSession: URLSession, logger: NetworkLogger) {
    let task = makeSessionTask(for: mockTask, urlSession: urlSession)
    if let dataTask = task as? URLSessionDataTask {
        logger.logDataTask(dataTask, didReceive: mockTask.response)
        logger.logDataTask(dataTask, didReceive: mockTask.responseBody)
    }

    let taskInterval = DateInterval(start: Date().addingTimeInterval(mockTask.delay), duration: mockTask.duration)
    let metrics = makeMetrics(for: mockTask, taskInterval: taskInterval)

    logger.logTask(task, didFinishCollecting: metrics)

    logger.logTask(task, didCompleteWithError: nil)
    if let error = mockTask.decodingError {
        logger.logTask(task, didFinishDecoding: .failure(error))
    } else {
        logger.logTask(task, didFinishDecoding: .success("success"))
    }
}

private func makeSessionTask(for mockTask: MockTask, urlSession: URLSession) -> URLSessionTask {
    let task: URLSessionTask
    switch mockTask.kind {
    case .data: task = urlSession.dataTask(with: mockTask.originalRequest)
    case .download: task = urlSession.downloadTask(with: mockTask.originalRequest)
    case .upload: task = urlSession.uploadTask(with: mockTask.originalRequest, from: Data())
    }
    task.setValue(mockTask.currentRequest, forKey: "currentRequest")
    task.setValue(mockTask.response, forKey: "response")
    return task
}

private func makeMetrics(for task: MockTask, taskInterval: DateInterval) -> NetworkLogger.Metrics {
    let redirectCount = task.transactions.filter {
        $0.fetchType == .networkLoad && ($0.response as? HTTPURLResponse)?.statusCode == 302
    }.count
    var currentDate = taskInterval.start
    let transactions: [NetworkLogger.TransactionMetrics] = task.transactions.enumerated().map { index, transaction in
        var metrics = NetworkLogger.TransactionMetrics(
            request: NetworkLogger.Request(transaction.request),
            response: NetworkLogger.Response(transaction.response),
            resourceFetchType: transaction.fetchType
        )
        if transaction.fetchType == .networkLoad {
            metrics.networkProtocolName = "http/2.0"
        }
        metrics.isReusedConnection = transaction.isReusedConnection
        metrics.fetchStartDate = currentDate
        func nextDate(delay: TimeInterval) -> Date {
            currentDate.addTimeInterval(delay / 1000 * TimeInterval.random(in: 0.9...1.1))
            return currentDate
        }
        func nextDate(percentage: TimeInterval) -> Date {
            let remaining = transaction.duration - currentDate.timeIntervalSince(metrics.fetchStartDate!)
            currentDate.addTimeInterval(remaining * percentage)
            return currentDate
        }
        func transactionEndDate() -> Date {
            currentDate = metrics.fetchStartDate!.addingTimeInterval(transaction.duration)
            return currentDate
        }

        let isLastTransaction = index == task.transactions.endIndex - 1
        let requestBodySize = Int64(transaction.request.httpBody?.count ?? 0)

        switch transaction.fetchType {
        case .networkLoad:
            if !transaction.isReusedConnection {
                metrics.domainLookupStartDate = nextDate(delay: 8)
                metrics.domainLookupEndDate = nextDate(delay: 20)
                metrics.connectStartDate = nextDate(delay: 0.5)
                metrics.secureConnectionStartDate = nextDate(delay: 20)
                metrics.secureConnectionEndDate = nextDate(delay: 100)
                metrics.connectEndDate = nextDate(delay: 0.5)
            }
            switch task.kind {
            case .download:
                metrics.requestStartDate = nextDate(delay: 0.5)
                metrics.requestEndDate = nextDate(delay: 30)
                metrics.responseStartDate = isLastTransaction ? nextDate(delay: 10) : nextDate(percentage: 0.95)
                metrics.responseEndDate = transactionEndDate()
            case .data:
                metrics.requestStartDate = nextDate(delay: 0.5)
                metrics.requestEndDate = nextDate(delay: requestBodySize > 0 ? 30 : 4)
                metrics.responseStartDate = (isLastTransaction && task.responseBody.count > 0) ? nextDate(percentage: 0.8) : nextDate(percentage: 0.95)
                metrics.responseEndDate = transactionEndDate()
            case .upload:
                metrics.responseStartDate = nextDate(percentage: 0.98)
                metrics.responseEndDate = transactionEndDate()
            }
        case .localCache:
            metrics.requestStartDate = nextDate(delay: 0.5)
            metrics.responseEndDate = transactionEndDate()
        default: break
        }

        metrics.networkProtocolName = "http/2.0"

        let requestHeaders = transaction.request.allHTTPHeaderFields
        let responseHeaders = (transaction.response as? HTTPURLResponse)?.allHeaderFields as? [String: String]
        let statusCode = (transaction.response as? HTTPURLResponse)?.statusCode

        var details = NetworkLogger.TransactionDetailedMetrics()
        if transaction.fetchType == .networkLoad  {
            details.countOfRequestHeaderBytesSent = getHeadersEstimatedSize(requestHeaders)
            details.countOfResponseHeaderBytesReceived = getHeadersEstimatedSize(responseHeaders)
            if index == task.transactions.endIndex - 1 && statusCode != 304 {
                switch task.kind {
                case .data, .download:
                    details.countOfRequestBodyBytesBeforeEncoding = requestBodySize
                    details.countOfRequestBodyBytesSent = Int64(Double(requestBodySize) * .random(in: 0.6...0.8))
                case .upload(let size):
                    details.countOfRequestBodyBytesBeforeEncoding = size
                    details.countOfRequestBodyBytesSent = size
                }
                switch task.kind {
                case .data, .upload:
                    details.countOfResponseBodyBytesAfterDecoding = Int64(task.responseBody.count)
                    details.countOfResponseBodyBytesReceived = Int64(Double(task.responseBody.count) * .random(in: 0.6...0.8))
                case .download(let size):
                    details.countOfResponseBodyBytesAfterDecoding = size
                    details.countOfResponseBodyBytesReceived = size
                }
            }
        }

        details.negotiatedTLSCipherSuite = tls_ciphersuite_t.AES_128_GCM_SHA256.rawValue
        details.negotiatedTLSProtocolVersion = tls_protocol_version_t.TLSv13.rawValue
        details.remoteAddress = "17.253.97.204"
        details.remotePort = 443
        details.localAddress = "192.168.0.13"
        details.localPort = 58622

        metrics.details = details

        return metrics
    }

    return NetworkLogger.Metrics(
        taskInterval: taskInterval,
        redirectCount: redirectCount,
        transactions: transactions
    )
}

private func getHeadersEstimatedSize(_ headers: [String: String]?) -> Int64 {
    Int64((headers ?? [:])
        .map { "\($0.key): \($0.value)" }
        .joined(separator: "\n")
        .data(using: .utf8)?
        .count ?? 0)
}

extension LoggerStore {
    func entity(for task: MockTask) -> LoggerNetworkRequestEntity {
        _logTask(task, urlSession: URLSession.shared, logger: NetworkLogger(store: self, isWaitingForDecoding: true))
        let entity = (try! allNetworkRequests()).first { $0.url == task.originalRequest.url?.absoluteString }
        assert(entity != nil)
        return entity!
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(milliseconds: Int) async {
        try! await sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}

#endif
