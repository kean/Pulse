// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import XCTest
@testable import Pulse

private struct Logger {
    let label: String
    let store: LoggerStore

    func log(level: LoggerStore.Level, _ message: String, metadata: LoggerStore.Metadata? = nil) {
        self.store.storeMessage(label: label, level: level, message: message, metadata: metadata, file: #file, function: #function, line: 0)
    }
}

extension XCTestCase {
    func populate(store: LoggerStore) {
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

    // Creates a good mix of messages with multiple sessions, blobs of different size, etc.
    func populateMix(store: LoggerStore) {
        assert(!store.configuration.isAutoStartingSession)
        assert(store.configuration.inlineLimit == ExportableStoreConstants.inlineLimit)

        let networkLogger = NetworkLogger(store: store)

        // Session #1
        store.startSession(ExportableStoreConstants.sessionOne, info: .make())

        Logger(label: "application", store: store).log(level: .trace, "message-trace-01")
        Logger(label: "application", store: store).log(level: .debug, "message-debug-01")
        Logger(label: "application", store: store).log(level: .error, "message-error-01")

        networkLogger.logTask(makeMockTask(with: "https://api.github.com/a", data: ExportableStoreConstants.blobA))

        networkLogger.logTask(makeMockTask(with: "https://api.github.com/b", data: ExportableStoreConstants.blobB))

        networkLogger.logTask(makeMockTask(with: "https://api.github.com/c", data: ExportableStoreConstants.blobC))

        // Session #1
        store.startSession(ExportableStoreConstants.sessionTwo, info: .make())

        Logger(label: "application", store: store).log(level: .debug, "message-debug-02", metadata: ["key-a": .string("1")])

        networkLogger.logTask(makeMockTask(with: "https://api.github.com/a", data: ExportableStoreConstants.blobA))

        networkLogger.logTask(makeMockTask(with: "https://api.github.com/c", data: ExportableStoreConstants.blobC))

        networkLogger.logTask(makeMockTask(with: "https://api.github.com/d", data: ExportableStoreConstants.blobD))
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
}

struct ExportableStoreConstants {
    static let sessionOne = LoggerStore.Session(
        id: UUID(uuidString: "1B39EDCF-DA05-4145-8389-63CC515C8664")!,
        startDate: ISO8601DateFormatter().date(from: "2033-01-05T08:42:07Z")!
    )

    static let sessionTwo = LoggerStore.Session(
        id: UUID(uuidString: "F8EA7E68-66C5-4AC6-8AC9-5C0CF5C4CC85")!,
        startDate: ISO8601DateFormatter().date(from: "2033-01-05T08:42:07Z")!
    )

    /// - warning: This is important to set to make sure some blobs are recorded as files.
    static let inlineLimit = 1000

    /// Recorded in session #1 and #2
    static let blobA = String(repeating: "A", count: 5000).data(using: .utf8)!

    /// Recorded in session #1
    static let blobB = String(repeating: "B", count: 7000).data(using: .utf8)!

    /// Recorded in session #1 and #2
    static let blobC = String(repeating: "C", count: 100).data(using: .utf8)!

    /// Recorded in session #2
    static let blobD = String(repeating: "D", count: 250).data(using: .utf8)!
}

extension NetworkLogger {
    func logTask(_ mockTask: MockDataTask, urlSession: URLSession = mockSession) {
        let dataTask = urlSession.dataTask(with: mockTask.request)
        dataTask.setValue(mockTask.response, forKey: "response")
        logTaskCreated(dataTask)
        logDataTask(dataTask, didReceive: mockTask.responseBody)
        logTask(dataTask, didFinishCollecting: mockTask.metrics)
        logTask(dataTask, didCompleteWithError: nil)
    }
}

private let mockSession: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.httpAdditionalHeaders = [
        "User-Agent": "Pulse Demo/0.19 iOS"
    ]
    return URLSession(configuration: .default)
}()
