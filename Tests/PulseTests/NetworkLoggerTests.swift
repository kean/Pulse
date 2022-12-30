// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import XCTest
import Combine
@testable import Pulse

final class NetworkLoggerTests: XCTestCase {
    let directory = TemporaryDirectory()
    var storeURL: URL!
    var store: LoggerStore!
    var logger: NetworkLogger!

    override func setUp() {
        super.setUp()

        try? FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true, attributes: nil)
        storeURL = directory.url.appending(filename: "test-store")
        store = try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous])

        logger = NetworkLogger(store: store)
    }

    override func tearDown() {
        super.tearDown()

        try? store.destroy()
        directory.remove()
    }

    func testCreatingDecodingError() throws {
        // GIVEN
        let data = """
        {
          "id": 1296269,
          "node": "MDEwOlJlcG9zaXRvcnkxMjk2MjY5"
        }
        """.data(using: .utf8)!

        struct Repo: Decodable {
            let id: String
            let node: String
        }

        // WHEN
        do {
            _ = try JSONDecoder().decode(Repo.self, from: data)
            XCTFail("Expected decoding to fail")
        } catch {
            let networkError = NetworkLogger.ResponseError(error)
            let encoded = try JSONEncoder().encode(networkError)
            let decoded = try JSONDecoder().decode(NetworkLogger.ResponseError.self, from: encoded)
            let decodingError = try XCTUnwrap(decoded.error as? NetworkLogger.DecodingError)
            switch decodingError {
            case let .typeMismatch(type, context):
                XCTAssertEqual(type, "String")
                XCTAssertEqual(context.codingPath, [.string("id")])
            default:
                XCTFail("Unexpected error: \(networkError)")
            }
        }
    }

    func testRedactingSentitiveHeaders() {
        // GIVEN
        var urlRequest = URLRequest(url: URL(string: "comexample.com")!)
        urlRequest.setValue("123", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("456", forHTTPHeaderField: "Content-Size")
        let request = NetworkLogger.Request(urlRequest)

        // WHEN
        let radacted = request.redactingSensitiveHeaders(["authorization"])

        // THEN
        XCTAssertEqual(radacted.headers, [
            "Authorization": "<private>",
            "Content-Size": "456"
        ])
    }

    func _testEncodingSize() throws {
        let task = MockDataTask.login
        let encoder = JSONEncoder()

        let request = try encoder.encode(NetworkLogger.Request(task.request))
        let response = try encoder.encode(NetworkLogger.Response(task.response))
        let metrics = try encoder.encode(task.metrics)
        let event = try encoder.encode(LoggerStore.Event.NetworkTaskCompleted(
            taskId: UUID(),
            taskType: .dataTask,
            createdAt: Date(),
            originalRequest: NetworkLogger.Request(task.request),
            currentRequest: nil,
            response: NetworkLogger.Response(task.response),
            error: nil,
            requestBody: nil,
            responseBody: nil,
            metrics: task.metrics,
            session: UUID()
        ))

        XCTAssertEqual(request.count, 325)
        XCTAssertEqual(response.count, 129)
        XCTAssertEqual(metrics.count, 987)
        XCTAssertEqual(event.count, 1625)

        // These values are slightly different across invocations
//        XCTAssertEqual(try request.compressed().count, 251, accuracy: 10)
//        XCTAssertEqual(try response.compressed().count, 298, accuracy: 10)
//        XCTAssertEqual(try metrics.compressed().count, 648, accuracy: 10)
//        XCTAssertEqual(try details.compressed().count, 910, accuracy: 20)

        func printJSON(_ json: Data) throws {
            let value = try JSONSerialization.jsonObject(with: json)
            let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])
            print(NSString(string: String(data: data, encoding: .utf8) ?? "–"))
        }

        try printJSON(event)
    }

    // MARK: Include/Exclude

    func testIncludedHosts() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.includedHosts = ["api.example.com"]
        }

        // WHEN
        logTask(url: "logging.example.com/path")
        logTask(url: "api.example.com")
        logTask(url: "pulse.com")
        logTask(url: "example.com.net")

        // THEN only included path is logged
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks.contains(where: { $0.url ==  "api.example.com" }))
    }

    func testIncludeHostsWildcard() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.includedHosts = ["*.example.com"]
        }

        // WHEN
        logTask(url: "logging.example.com")
        logTask(url: "api.example.com")
        logTask(url: "pulse.com")

        // THEN only included path is logged
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.contains(where: { $0.url ==  "api.example.com" }))
        XCTAssertTrue(tasks.contains(where: { $0.url ==  "logging.example.com" }))
    }

    func testIncludeHostsRegex() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.includedHosts = ["(logging|api).example.com"]
            $0.isRegexEnabled = true
        }

        // WHEN
        logTask(url: "logging.example.com")
        logTask(url: "api.example.com")
        logTask(url: "pulse.com")

        // THEN only included path is logged
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 2)
        XCTAssertTrue(tasks.contains(where: { $0.url ==  "api.example.com" }))
        XCTAssertTrue(tasks.contains(where: { $0.url ==  "logging.example.com" }))
    }

    func testExcludeHosts() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.excludedHosts = ["*.example.com"]
        }

        // WHEN
        logTask(url: "logging.example.com")
        logTask(url: "api.example.com")
        logTask(url: "pulse.com")

        // THEN only included path is logged
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks.contains(where: { $0.url ==  "pulse.com" }))
    }

    func testIncludeAndExcludeHosts() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.includedHosts = ["*.example.com"]
            $0.excludedHosts = ["logging.example.com"]
        }

        // WHEN
        logTask(url: "logging.example.com")
        logTask(url: "api.example.com")
        logTask(url: "pulse.com")

        // THEN only included path is logged
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(tasks.contains(where: { $0.url ==  "api.example.com" }))
    }

    func testExcludeSensitiveHeaders() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.sensitiveHeaders = ["Password", "Set-Cookie", "X-*"]
        }

        // WHEN
        let url = URL(string: "example.com/login")!
        var request = URLRequest(url: URL(string: "example.com/login")!)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("123456", forHTTPHeaderField: "Password")

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "http/2.0", headerFields: [
            "Set-Cookie": "token=123",
            "Content-Type": "JSON",
            "X-Name": "hello"
        ])

        let dataTask = URLSession.shared.dataTask(with: request)
        dataTask.setValue(request, forKey: "currentRequest")
        dataTask.setValue(response, forKey: "response")

        logger.logTask(dataTask, didFinishCollecting: MockDataTask.login.metrics)
        logger.logTask(dataTask, didCompleteWithError: nil)

        // THEN sensitive headers are redacted from both requests and responses
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)
        let task = try XCTUnwrap(tasks.first)

        XCTAssertEqual(task.originalRequest?.headers, [
            "Password": "<private>",
            "Content-Type": "application/json"
        ])
        XCTAssertEqual(task.currentRequest?.headers, [
            "Password": "<private>",
            "Content-Type": "application/json"
        ])
        XCTAssertEqual(task.response?.headers, [
            "Set-Cookie": "<private>",
            "X-Name": "<private>",
            "Content-Type": "JSON"
        ])
        let responseFromMetrics = try XCTUnwrap(task.transactions.first(where: {
            $0.response?.headers.keys.contains("Set-Cookie") ?? false
        })?.response)
        XCTAssertEqual(responseFromMetrics.headers, [
            "Set-Cookie": "<private>"
        ])
    }

    func testExcludeSentitiveQueryItems() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.sensitiveQueryItems = ["password"]
        }

        // WHEN
        let request = URLRequest(url: URL(string: "api.example.com/path?password=123456&mobile=true")!)
        let dataTask = URLSession.shared.dataTask(with: request)
        logger.logTask(dataTask, didFinishCollecting: MockDataTask.login.metrics)
        logger.logTask(dataTask, didCompleteWithError: nil)

        // THEN only included path is logged
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)
        let task = try XCTUnwrap(tasks.first)
        do {
            let url = try XCTUnwrap(URL(string: task.originalRequest?.url ?? ""))
            let queryItem = try XCTUnwrap(url.queryItems.first(where: { $0.name == "password" }))
            XCTAssertEqual(queryItem.value, "private")
        }
        do {
            let url = try XCTUnwrap(URL(string: task.currentRequest?.url ?? ""))
            let queryItem = try XCTUnwrap(url.queryItems.first(where: { $0.name == "password" }))
            XCTAssertEqual(queryItem.value, "private")
        }
        do {
            XCTAssertEqual(task.transactions.count, 1)
            let request = try XCTUnwrap(task.transactions.first?.request)
            let url = try XCTUnwrap(URL(string: request.url ?? ""))
            let queryItem = try XCTUnwrap(url.queryItems.first(where: { $0.name == "password" }))
            XCTAssertEqual(queryItem.value, "private")
        }
    }

    func testExcludeSensitiveResponseFields() throws {
        // GIVEN
        logger = NetworkLogger(store: store) {
            $0.sensitiveDataFields = ["access-token", "refresh-token"]
        }

        // WHEN
        let mockTask = MockDataTask.login
        let dataTask = URLSession.shared.dataTask(with: mockTask.request)
        dataTask.setValue(mockTask.request, forKey: "currentRequest")
        dataTask.setValue(mockTask.response, forKey: "response")
        logger.logDataTask(dataTask, didReceive: mockTask.responseBody)
        logger.logTask(dataTask, didFinishCollecting: mockTask.metrics)
        logger.logTask(dataTask, didFinishDecodingWithError: nil)

        // THEN sensitive response fields are redacted from both requests and responses
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 1)
        let task = try XCTUnwrap(tasks.first)
        let data = try XCTUnwrap(task.responseBody?.data)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"access-token\":\"<private>\""))
        XCTAssertTrue(json.contains("\"refresh-token\":\"<private>\""))
    }

    // MARK: Helpers

    func logTask(url: String) {
        let request = URLRequest(url: URL(string: url)!)
        let task = URLSession.shared.dataTask(with: request)
        logger.logTask(task, didCompleteWithError: nil)
    }
}

private extension URL {
    var queryItems: [URLQueryItem] {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }
}
