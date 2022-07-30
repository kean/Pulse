// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import CoreData
import XCTest
import Logging
import Combine
@testable import Pulse
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
            let error = NetworkLoggerError(error)
            let encoded = try JSONEncoder().encode(error)
            let decoded = try JSONDecoder().decode(NetworkLoggerError.self, from: encoded)
            let decodingError = try XCTUnwrap(decoded.error as? NetworkLoggerDecodingError)
            switch decodingError {
            case let .typeMismatch(type, context):
                XCTAssertEqual(type, "String")
                XCTAssertEqual(context.codingPath, [.string("id")])
            default:
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
