// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse

extension LoggerStore {
    package static let test: LoggerStore = {
        let store = try! LoggerStore(
            storeURL: URL(fileURLWithPath: "/dev/null/\(UUID().uuidString)"),
            options: [.create, .inMemory, .synchronous]
        )
        _populate(store: store)
        return store
    }()
}

private struct Logger {
    let label: String
    let store: LoggerStore

    func log(level: LoggerStore.Level, _ message: String, metadata: LoggerStore.Metadata? = nil) {
        self.store.storeMessage(label: label, level: level, message: message, metadata: metadata, file: #file, function: #function, line: 0)
    }
}

public func _populate(store: LoggerStore) {
    func logger(named: String) -> Logger {
        Logger(label: named, store: store)
    }

    logger(named: "application")
        .log(level: .info, "UIApplication.didFinishLaunching")

    logger(named: "application")
        .log(level: .info, "UIApplication.willEnterForeground")

    logger(named: "auth")
        .log(level: .trace, "Instantiated Session")

    logger(named: "auth")
        .log(level: .trace, "Instantiated the new login request")

    let networkLogger = NetworkLogger(store: store)

    networkLogger.logTask(MockDataTask.login)

    logger(named: "analytics")
        .log(level: .debug, "Will navigate to Dashboard")

    networkLogger.logTask(MockDataTask.octocat)

    networkLogger.logTask(MockDataTask.profileFailure)

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

private func makeMockTask(with url: String, data: Data) -> MockDataTask {
    let url = URL(string: url)!
    let request = URLRequest(url: url)
    let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

    return MockDataTask(
        request: request,
        response: response,
        responseBody: data,
        metrics: makeMetrics(with: url.absoluteString)
    )
}

private func makeMetrics(with url: String) -> NetworkLogger.Metrics {
    var metrics = MockDataTask.login.metrics
    metrics.transactions = metrics.transactions.map {
        var transaction = $0
        transaction.request = .init(URLRequest(url: URL(string: url)!))
        transaction.response = .init(HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        return transaction
    }
    return metrics
}

public struct ExportableStoreConstants {
    public static let sessionOne = LoggerStore.Session(
        id: UUID(uuidString: "1B39EDCF-DA05-4145-8389-63CC515C8664")!,
        startDate: ISO8601DateFormatter().date(from: "2033-01-05T08:42:07Z")!
    )

    public static let sessionTwo = LoggerStore.Session(
        id: UUID(uuidString: "F8EA7E68-66C5-4AC6-8AC9-5C0CF5C4CC85")!,
        startDate: ISO8601DateFormatter().date(from: "2033-01-05T08:42:07Z")!
    )

    /// - warning: This is important to set to make sure some blobs are recorded as files.
    public static let inlineLimit = 1000

    /// Recorded in session #1 and #2
    public static let blobA = String(repeating: "A", count: 5000).data(using: .utf8)!

    /// Recorded in session #1
    public static let blobB = String(repeating: "B", count: 7000).data(using: .utf8)!

    /// Recorded in session #1 and #2
    public static let blobC = String(repeating: "C", count: 100).data(using: .utf8)!

    /// Recorded in session #2
    public static let blobD = String(repeating: "D", count: 250).data(using: .utf8)!
}

extension NetworkLogger {
    public func logTask(_ mockTask: MockDataTask, urlSession: URLSession = mockSession) {
        let dataTask = urlSession.dataTask(with: mockTask.request)
        dataTask.setValue(mockTask.response, forKey: "response")
        logTaskCreated(dataTask)
        logDataTask(dataTask, didReceive: mockTask.responseBody)
        logTask(dataTask, didFinishCollecting: mockTask.metrics)
        logTask(dataTask, didCompleteWithError: nil)
    }
}

public let mockSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.httpAdditionalHeaders = [
        "User-Agent": "Pulse Demo/0.19 iOS"
    ]
    return URLSession(configuration: .default)
}()
