// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import XCTest
import Combine
@testable import PulseCore

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
}
