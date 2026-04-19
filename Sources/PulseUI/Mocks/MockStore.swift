// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import SwiftUI

#if DEBUG || STANDALONE_PULSE_APP

extension LoggerStore {
    package static let mock: LoggerStore = {
        var configuration = LoggerStore.Configuration()
        configuration.isAutoStartingSession = false
        let store = makeMockStore(configuration: configuration)
        _syncPopulateStore(store)
        return store
    }()


    package static let preview = makeMockStore()

    package func populate() {
        _syncPopulateStore(self)
    }
}

/// Sample ``ConsoleDelegate`` used by previews and demos. For GraphQL
/// requests, it surfaces the operation name — conventionally stored on
/// `URLSessionTask.taskDescription` for debugging — as the cell's main
/// content via ``ConsoleListDisplaySettings/ContentSettings/customText``.
@MainActor
package final class MockConsoleDelegate: ConsoleDelegate {
    package static let shared = MockConsoleDelegate()

    package func console(listDisplayOptionsFor task: NetworkTaskEntity) -> ConsoleListDisplaySettings {
        if task.url?.contains("/graphql") == true,
           let operationName = task.taskDescription, !operationName.isEmpty {
            var options = ConsoleListDisplaySettings()
            options.content.showMethod = false
            options.content.customText = operationName
            options.footer.fields = [.url(components: [.host, .path])]
            return options
        }
        return UserSettings.shared.listDisplayOptions
    }

    package func console(inspectorViewFor task: NetworkTaskEntity) -> AnyView? {
        guard task.url?.contains("/graphql") == true,
              let operationName = task.taskDescription, !operationName.isEmpty else {
            return nil
        }
        return AnyView(
            Section("GraphQL") {
                HStack {
                    Text("Operation")
                    Spacer()
                    Text(operationName).foregroundStyle(.secondary)
                }
            }
        )
    }

    package func console(responseBodyViewFor task: NetworkTaskEntity) -> AnyView? {
        guard task.response?.contentType?.isProtobuf == true,
              let data = task.responseBody?.data, !data.isEmpty else {
            return nil
        }
        return AnyView(MockProtobufResponseView(
            typeName: task.response?.headers["X-Grpc-Message-Type"],
            data: data
        ))
    }

    package func console(redact value: String, field: ConsoleRedactionField, for task: NetworkTaskEntity) -> String {
        switch field {
        case .requestHeader("Authorization"), .requestHeader("Cookie"),
             .responseHeader("Set-Cookie"):
            return "***"
        default:
            return value
        }
    }

    package func console(contextMenuFor task: NetworkTaskEntity) -> AnyView? {
        guard task.url?.contains("/graphql") == true,
              let operationName = task.taskDescription, !operationName.isEmpty else {
            return nil
        }
        return AnyView(
            Section("GraphQL") {
                Button {
#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
                    UIPasteboard.general.string = operationName
#elseif canImport(AppKit)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(operationName, forType: .string)
#endif
                } label: {
                    Label("Copy Operation Name", systemImage: "doc.on.doc")
                }
            }
        )
    }
}

/// Stand-in for an integrator's protobuf-decoded response view. In a real
/// app this would decode `data` using generated `SwiftProtobuf` types and
/// render a field tree; here we just pretty-print the parsed fields so the
/// demo shows what `responseBodyViewFor` looks like end-to-end.
@MainActor
private struct MockProtobufResponseView: View {
    let typeName: String?
    let data: Data

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let typeName {
                    Text(typeName)
                        .font(.system(.headline, design: .monospaced))
                }
                Text(decoded)
                    .font(.system(.callout, design: .monospaced))
#if !os(watchOS) && !os(tvOS)
                    .textSelection(.enabled)
#endif
                    .frame(maxWidth: .infinity, alignment: .leading)
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Raw (\(data.count) bytes)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(data.map { String(format: "%02x", $0) }.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
#if !os(watchOS) && !os(tvOS)
                        .textSelection(.enabled)
#endif
                }
            }
            .padding()
        }
    }

    private var decoded: String {
        """
        {
          id: 1567433
          username: "kean"
          email: "alex@example.com"
          roles: ["owner", "maintainer"]
          profile {
            display_name: "Alex Kean"
            followers: 354
            verified: true
          }
        }
        """
    }
}

extension LoggerStore {
    package static let demo: LoggerStore = {
        let store = LoggerStore.shared
        store.startPopulating()
        return store
    }()

    func startPopulating(isIndefinite: Bool = false) {
        func populate() {
            asyncPopulateStore(self)
            if isIndefinite {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(12)) {
                    populate()
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            populate()
        }
    }
}

private let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("pulseui-demo")

private let cleanup: Void = {
    try? FileManager.default.removeItem(at: rootURL)
    try! FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
}()

private func makeMockStore(configuration: LoggerStore.Configuration = .init()) -> LoggerStore {
    _ = cleanup

    let storeURL = rootURL.appendingPathComponent("\(UUID().uuidString).pulse")
    return try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous], configuration: configuration)
}

private struct Logger {
    let label: String
    let store: LoggerStore

    func log(level: LoggerStore.Level, _ message: String, metadata: LoggerStore.Metadata? = nil) {
        self.store.storeMessage(label: label, level: level, message: message, metadata: metadata, file: #file, function: #function, line: #line)
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

    let networkLogger = NetworkLogger(store: store, configuration: {
        var configuration = NetworkLogger.Configuration()
        configuration.isWaitingForDecoding = true
        return configuration
    }())

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

        logger(named: "session")
            .log(level: .trace, "Instantiated Session")

        logger(named: "auth")
            .log(level: .trace, "Instantiated the new login request")

        await Task.sleep(milliseconds: 800)

        logger(named: "analytics")
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

    await Task.sleep(milliseconds: 10000)

    logger(named: "auth")
        .log(level: .warning, .init(stringLiteral: stackTrace))

    logger(named: "default")
        .log(level: .critical, "💥 0xDEADBEEF")
}

private func _syncPopulateStore(_ store: LoggerStore) {
    func logger(named: String) -> Logger {
        Logger(label: named, store: store)
    }

    let networkLogger = NetworkLogger(store: store, configuration: {
        var configuration = NetworkLogger.Configuration()
        configuration.isWaitingForDecoding = true
        return configuration
    }())

    let urlSession = URLSession(configuration: .default)
    let now = Date()

    // MARK: - Session 1: Startup & Browse (2 days ago)

    store.startSession(.init(startDate: now.addingTimeInterval(-2 * 24 * 3600)), info: .current)

    logger(named: "application")
        .log(level: .info, "UIApplication.didFinishLaunching", metadata: [
            "environment": .string("production")
        ])

    logger(named: "application")
        .log(level: .info, "UIApplication.willEnterForeground")

    logger(named: "session")
        .log(level: .trace, "Instantiated Session")

    logger(named: "auth")
        .log(level: .trace, "Checking stored credentials")

    logger(named: "auth")
        .log(level: .debug, "Token expired, re-authenticating")

    _logTask(.login, urlSession: urlSession, logger: networkLogger)

    logger(named: "auth")
        .log(level: .info, "Successfully authenticated user", metadata: [
            "user_id": .string("12345"),
            "method": .string("password")
        ])

    logger(named: "analytics")
        .log(level: .debug, "Will navigate to Dashboard")

    _logTask(.repos, urlSession: urlSession, logger: networkLogger)
    _logTask(.octocat, urlSession: urlSession, logger: networkLogger)
    _logTask(.searchRepos, urlSession: urlSession, logger: networkLogger)

    logger(named: "analytics")
        .log(level: .debug, "Will navigate to Notifications")

    _logTask(.notifications, urlSession: urlSession, logger: networkLogger)
    _logTask(.starRepo, urlSession: urlSession, logger: networkLogger)

    logger(named: "cache")
        .log(level: .trace, "Image cached to disk", metadata: [
            "key": .string("octocat_avatar"),
            "size_bytes": .string("6789")
        ])

    // MARK: - Session 2: API Issues (6 hours ago)

    store.startSession(.init(startDate: now.addingTimeInterval(-6 * 3600)), info: .current)

    logger(named: "application")
        .log(level: .info, "UIApplication.didFinishLaunching")

    logger(named: "application")
        .log(level: .info, "UIApplication.willEnterForeground")

    logger(named: "session")
        .log(level: .trace, "Instantiated Session")

    logger(named: "auth")
        .log(level: .debug, "Using cached auth token")

    logger(named: "analytics")
        .log(level: .debug, "Will navigate to Profile")

    _logTask(.profile, urlSession: urlSession, logger: networkLogger)

    logger(named: "network")
        .log(level: .warning, "Profile endpoint returned 404 — user profile may not exist")

    _logTask(.pullRequests, urlSession: urlSession, logger: networkLogger)
    _logTask(.issues, urlSession: urlSession, logger: networkLogger)
    _logTask(.userOrgs, urlSession: urlSession, logger: networkLogger)
    _logTask(.gists, urlSession: urlSession, logger: networkLogger)

    logger(named: "sync")
        .log(level: .info, "Starting data export")

    _logTask(.uploadPulseArchive, urlSession: urlSession, logger: networkLogger)

    logger(named: "sync")
        .log(level: .info, "Data export completed", metadata: [
            "archive_size": .string("21.8 MB"),
            "duration_ms": .string("2890")
        ])

    logger(named: "api")
        .log(level: .debug, "Creating new API token")

    _logTask(.createAPI, urlSession: urlSession, logger: networkLogger)

    logger(named: "api")
        .log(level: .info, "API token created successfully")

    logger(named: "api")
        .log(level: .debug, "Updating repository metadata")


    _logTask(.deleteRepo, urlSession: urlSession, logger: networkLogger)

    logger(named: "network")
        .log(level: .warning, "DELETE /repos/kean/deprecated-project returned 403 Forbidden")

    // MARK: - Session 3: Latest Session (current)

    store.startSession(.init(startDate: now.addingTimeInterval(-120)), info: .current)

    logger(named: "application")
        .log(level: .info, "UIApplication.didFinishLaunching", metadata: [
            "custom-metadata-key": .string("value")
        ])

    logger(named: "application")
        .log(level: .info, "UIApplication.willEnterForeground")

    logger(named: "session")
        .log(level: .trace, "Instantiated Session")

    logger(named: "database")
        .log(level: .debug, "Running pending database migrations", metadata: [
            "from_version": .string("12"),
            "to_version": .string("14")
        ])

    logger(named: "database")
        .log(level: .info, "Database migration completed")

    logger(named: "auth")
        .log(level: .trace, "Instantiated the new login request")

    _logTask(.protoUser, urlSession: urlSession, logger: networkLogger)

    _logTask(.downloadNuke, urlSession: urlSession, logger: networkLogger)

    logger(named: "auth")
        .log(level: .info, "Login successful")

    logger(named: "analytics")
        .log(level: .debug, "Will navigate to Dashboard")

    _logTask(.userEvents, urlSession: urlSession, logger: networkLogger)
    _logTask(.followers, urlSession: urlSession, logger: networkLogger)
    _logTask(.rateLimit, urlSession: urlSession, logger: networkLogger)

    logger(named: "feed")
        .log(level: .debug, "Loading repository feed")

    _logTask(.releaseLatest, urlSession: urlSession, logger: networkLogger)
    _logTask(.repoContributors, urlSession: urlSession, logger: networkLogger)
    _logTask(.labels, urlSession: urlSession, logger: networkLogger)

    logger(named: "analytics")
        .log(level: .debug, "Will navigate to Profile")

    _logTask(.updateProfile, urlSession: urlSession, logger: networkLogger)
    _logTask(.graphQL, urlSession: urlSession, logger: networkLogger)

    logger(named: "sync")
        .log(level: .debug, "Initiating background sync")

    _logTask(.createIssue, urlSession: urlSession, logger: networkLogger)
    _logTask(.mergeRequest, urlSession: urlSession, logger: networkLogger)

    logger(named: "sync")
        .log(level: .info, "Background sync completed", metadata: [
            "files_synced": .string("3"),
            "total_size": .string("6.4 MB")
        ])

    logger(named: "analytics")
        .log(level: .debug, "Will navigate to Settings")

    _logTask(.rateLimitExceeded, urlSession: urlSession, logger: networkLogger)

    _logTask(.patchRepo, urlSession: urlSession, logger: networkLogger)

    logger(named: "api")
        .log(level: .error, "Failed to decode response: keyNotFound(\"updated_at\", Swift.DecodingError.Context(codingPath: [], debugDescription: \"No value associated with key\"))")

    logger(named: "network")
        .log(level: .error, "API rate limit exceeded — retry after 60s")

    _logTask(.serverError, urlSession: urlSession, logger: networkLogger)

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
            logger.logDataTask(dataTask, didReceive: mockTask.responseBody)
        }

        let taskInterval = DateInterval(start: startDate, duration: mockTask.duration)
        let metrics = makeMetrics(for: mockTask, taskInterval: taskInterval)
        logger.logTask(task, didFinishCollecting: metrics)
        logger.logTask(task, didCompleteWithError: nil)

        await Task.sleep(milliseconds: 50)

        logger.logTask(task, didFinishDecodingWithError: mockTask.decodingError)
    }

    Task.detached {
        await logTask()
    }
}

private func _logTask(_ mockTask: MockTask, urlSession: URLSession, logger: NetworkLogger) {
    let task = makeSessionTask(for: mockTask, urlSession: urlSession)
    if let dataTask = task as? URLSessionDataTask {
        logger.logDataTask(dataTask, didReceive: mockTask.responseBody)
    }

    let taskInterval = DateInterval(start: Date().addingTimeInterval(mockTask.delay), duration: mockTask.duration)
    let metrics = makeMetrics(for: mockTask, taskInterval: taskInterval)

    logger.logTask(task, didFinishCollecting: metrics)

    logger.logTask(task, didCompleteWithError: nil)
    logger.logTask(task, didFinishDecodingWithError: mockTask.decodingError)
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
    task.taskDescription = mockTask.taskDescription
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
            metrics.networkProtocol = "http/2.0"
        }
        if transaction.isReusedConnection {
            metrics.conditions.insert(.isReusedConnection)
        }
        var timing = NetworkLogger.TransactionTimingInfo()
        timing.fetchStartDate = currentDate
        func nextDate(delay: TimeInterval) -> Date {
            currentDate.addTimeInterval(delay / 1000 * TimeInterval.random(in: 0.9...1.1))
            return currentDate
        }
        func nextDate(percentage: TimeInterval) -> Date {
            let remaining = transaction.duration - currentDate.timeIntervalSince(timing.fetchStartDate!)
            currentDate.addTimeInterval(remaining * percentage)
            return currentDate
        }
        func transactionEndDate() -> Date {
            currentDate = timing.fetchStartDate!.addingTimeInterval(transaction.duration)
            return currentDate
        }

        let isLastTransaction = index == task.transactions.endIndex - 1
        let requestBodySize = Int64(transaction.request.httpBody?.count ?? 0)

        switch transaction.fetchType {
        case .networkLoad:
            if !transaction.isReusedConnection {
                timing.domainLookupStartDate = nextDate(delay: 8)
                timing.domainLookupEndDate = nextDate(delay: 20)
                timing.connectStartDate = nextDate(delay: 0.5)
                timing.secureConnectionStartDate = nextDate(delay: 20)
                timing.secureConnectionEndDate = nextDate(delay: 100)
                timing.connectEndDate = nextDate(delay: 0.5)
            }
            switch task.kind {
            case .download:
                timing.requestStartDate = nextDate(delay: 0.5)
                timing.requestEndDate = nextDate(delay: 30)
                timing.responseStartDate = isLastTransaction ? nextDate(delay: 10) : nextDate(percentage: 0.95)
                timing.responseEndDate = transactionEndDate()
            case .data:
                timing.requestStartDate = nextDate(delay: 0.5)
                timing.requestEndDate = nextDate(delay: requestBodySize > 0 ? 30 : 4)
                timing.responseStartDate = (isLastTransaction && task.responseBody.count > 0) ? nextDate(percentage: 0.8) : nextDate(percentage: 0.95)
                timing.responseEndDate = transactionEndDate()
            case .upload:
                timing.responseStartDate = nextDate(percentage: 0.98)
                timing.responseEndDate = transactionEndDate()
            }
        case .localCache:
            timing.requestStartDate = nextDate(delay: 0.5)
            timing.responseEndDate = transactionEndDate()
        default: break
        }
        metrics.timing = timing
        metrics.networkProtocol = "http/2.0"

        let requestHeaders = transaction.request.allHTTPHeaderFields
        let responseHeaders = (transaction.response as? HTTPURLResponse)?.allHeaderFields as? [String: String]
        let statusCode = (transaction.response as? HTTPURLResponse)?.statusCode

        var transferSize = NetworkLogger.TransferSizeInfo()
        if transaction.fetchType == .networkLoad {
            transferSize.requestHeaderBytesSent = getHeadersEstimatedSize(requestHeaders)
            transferSize.responseHeaderBytesReceived = getHeadersEstimatedSize(responseHeaders)
            if index == task.transactions.endIndex - 1 && statusCode != 304 {
                switch task.kind {
                case .data, .download:
                    transferSize.requestBodyBytesBeforeEncoding = requestBodySize
                    transferSize.requestBodyBytesSent = Int64(Double(requestBodySize) * 0.7)
                case .upload(let size):
                    transferSize.requestBodyBytesBeforeEncoding = size
                    transferSize.requestBodyBytesSent = size
                }
                switch task.kind {
                case .data, .upload:
                    transferSize.responseBodyBytesAfterDecoding = Int64(task.responseBody.count)
                    transferSize.responseBodyBytesReceived = Int64(Double(task.responseBody.count) * 0.7)
                case .download(let size):
                    transferSize.responseBodyBytesAfterDecoding = size
                    transferSize.responseBodyBytesReceived = size
                }
            }
        }
        metrics.transferSize = transferSize

        metrics.remoteAddress = "17.253.97.204"
        metrics.remotePort = 443
        metrics.localAddress = "192.168.0.13"
        metrics.localPort = 58622
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
    package func entity(for task: MockTask) -> NetworkTaskEntity {
        var configuration = NetworkLogger.Configuration()
        configuration.isWaitingForDecoding = true
        _logTask(task, urlSession: URLSession.shared, logger: NetworkLogger(store: self, configuration: configuration))
        let task = (try! tasks()).first { $0.url == task.originalRequest.url?.absoluteString }
        assert(task != nil)
        return task!
    }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(milliseconds: Int) async {
        try! await sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
}

#endif
