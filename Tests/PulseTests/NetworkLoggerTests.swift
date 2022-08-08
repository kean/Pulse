// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import XCTest
import Combine
@testable import Pulse

final class NetworkLoggerTests: XCTestCase {
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

    func testEncodingSize() throws {
        let task = MockDataTask.login
        let encoder = JSONEncoder()

        let request = try encoder.encode(NetworkLogger.Request(task.request))
        let response = try encoder.encode(NetworkLogger.Response(task.response))
        let metrics = try encoder.encode(task.metrics)
        let details = try encoder.encode(LoggerNetworkRequestEntity.RequestDetails(originalRequest: NetworkLogger.Request(task.request), currentRequest: NetworkLogger.Request(task.request), response: NetworkLogger.Response(task.response), error: .init(URLError(.badURL)), metrics: task.metrics, metadata: ["customKey":"customValue"]))

        XCTAssertEqual(request.count, 267)
        XCTAssertEqual(response.count, 294)
        XCTAssertEqual(metrics.count, 843)
        XCTAssertEqual(details.count, 1830)

        // These values are slightly different across invocations
//        XCTAssertEqual(try request.compressed().count, 251, accuracy: 10)
//        XCTAssertEqual(try response.compressed().count, 298, accuracy: 10)
//        XCTAssertEqual(try metrics.compressed().count, 648, accuracy: 10)
//        XCTAssertEqual(try details.compressed().count, 910, accuracy: 20)

        func printJSON(_ json: Data) throws {
            let value = try JSONSerialization.jsonObject(with: json)
            let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted])
            debugPrint(NSString(string: String(data: data, encoding: .utf8) ?? "–"))
        }

        try printJSON(details)
    }
}
