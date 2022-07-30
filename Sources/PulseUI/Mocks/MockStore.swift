// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

#if DEBUG || PULSE_DEMO

extension LoggerStore {
    static let mock: LoggerStore = {
        let store: LoggerStore = MockStoreConfiguration.isUsingDefaultStore ? .default : makeMockStore()

        if MockStoreConfiguration.isDelayingLogs {
            func populate() {
                populateStore(store)
                if !MockStoreConfiguration.isIndefinite {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10)) {
                        populate()
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(750)) {
                populate()
            }
        } else {
            populateStore(store)
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

private func populateStore(_ store: LoggerStore) {
    Task { @MainActor in
        await _populateStore(store)
    }
}

private func _populateStore(_ store: LoggerStore) async {
    @Sendable func logger(named: String) -> Logger {
        Logger(label: named, store: store)
    }

    let networkLogger = NetworkLogger(store: store)

    let urlSession = URLSession(configuration: .default)

    if isFirstLog {
        isFirstLog = false
        logger(named: "application")
            .log(level: .info, "UIApplication.didFinishLaunching", metadata: [
                "custom-metadata-key": .string("value")
            ])

        logger(named: "application")
            .log(level: .info, "UIApplication.willEnterForeground")

        if MockStoreConfiguration.isDelayingLogs { await Task.sleep(milliseconds: 300) }

        logger(named: "auth")
            .log(level: .trace, "Instantiated Session")

        logger(named: "auth")
            .log(level: .trace, "Instantiated the new login request")

        if MockStoreConfiguration.isDelayingLogs { await Task.sleep(milliseconds: 800) }

        logger(named: "application")
                .log(level: .debug, "Will navigate to Dashboard")
    }

    func logTask(_ mockTask: MockTask, delay: Int = Int.random(in: 1000...6000)) {
        _logTask(mockTask, urlSession: urlSession, logger: networkLogger, delay: delay)
    }

    logTask(MockTask.login, delay: 200)

    logTask(MockTask.octocat)

    if Bundle.main.url(forResource: "repos", withExtension: "json") != nil {
        logTask(MockTask.repos, delay: 1000)
    }

    logTask(MockTask.downloadNuke, delay: 3000)

    logTask(MockTask.profileFailure, delay: 200)

    logTask(MockTask.createAPI)

    logTask(MockTask.uploadPulseArchive)

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

    if MockStoreConfiguration.isDelayingLogs { await Task.sleep(milliseconds: 3000) }

    logger(named: "default")
        .log(level: .critical, "💥 0xDEADBEEF")
}

private func _logTask(_ mockTask: MockTask, urlSession: URLSession, logger: NetworkLogger, delay: Int) {
    let task = makeSessionTask(for: mockTask, urlSession: urlSession)

    @Sendable func logTask() async {
        if MockStoreConfiguration.isDelayingLogs {
            await Task.sleep(milliseconds: delay)
        }
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
        logger.logTask(task, didFinishCollecting: mockTask.metrics)
        logger.logTask(task, didCompleteWithError: nil)
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
    logger.logTask(task, didFinishCollecting: mockTask.metrics)
    logger.logTask(task, didCompleteWithError: nil)
}

private func makeSessionTask(for mockTask: MockTask, urlSession: URLSession) -> URLSessionTask {
    let task: URLSessionTask
    switch mockTask.kind {
    case .data: task = urlSession.dataTask(with: mockTask.request)
    case .download: task = urlSession.downloadTask(with: mockTask.request)
    case .upload: task = urlSession.uploadTask(with: mockTask.request, from: Data())
    }
    var currentRequest = mockTask.currentRequest
    currentRequest.setValue("Pulse Demo/2.0", forHTTPHeaderField: "User-Agent")

    task.setValue(currentRequest, forKey: "currentRequest")
    task.setValue(mockTask.response, forKey: "response")
    return task
}

extension LoggerStore {
    func entity(for task: MockTask) -> LoggerNetworkRequestEntity {
        _logTask(task, urlSession: URLSession.shared, logger: NetworkLogger(store: self))
        let entity = (try! allNetworkRequests()).first { $0.url == task.request.url?.absoluteString }
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
