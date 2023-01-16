// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import PulseUI

final class ConsoleSearchTokenTests: XCTestCase {
    func testStatusCodeFilter() throws {
        func parse(_ string: String) -> ConsoleSearchFilter.StatusCode? {
            try? Parsers.filterStatusCode.parse(string)
        }

        typealias StatusCode = ConsoleSearchFilter.StatusCode

        XCTAssertEqual(parse("S"), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("s"), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("s "), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("sta "), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("status "), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("stAtus "), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("stAtus co"), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("stAtus co:"), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("stAtus codE:"), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("status code: "), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("status code:   "), StatusCode(isNot: false, values: []))
        XCTAssertEqual(parse("   status   code:   "), StatusCode(isNot: false, values: []))

        // Exact value
        XCTAssertEqual(parse("s200"), StatusCode(isNot: false, values: [.exact(200)]))
        XCTAssertEqual(parse("s 200"), StatusCode(isNot: false, values: [.exact(200)]))

        // Closed range
        XCTAssertEqual(parse("s 200-300"), StatusCode(isNot: false, values: [.closedRange(lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200<=300"), StatusCode(isNot: false, values: [.closedRange(lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200..300"), StatusCode(isNot: false, values: [.closedRange(lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200...300"), StatusCode(isNot: false, values: [.closedRange(lowerBound: 200, upperBound: 300)]))

        // Open range
        XCTAssertEqual(parse("s 200<300"), StatusCode(isNot: false, values: [.openRange(lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200<300"), StatusCode(isNot: false, values: [.openRange(lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200.<300"), StatusCode(isNot: false, values: [.openRange(lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200..<300"), StatusCode(isNot: false, values: [.openRange(lowerBound: 200, upperBound: 300)]))

        // List of values
        XCTAssertEqual(parse("s 200 201"), StatusCode(isNot: false, values: [.exact(200), .exact(201)]))
        XCTAssertEqual(parse("s 200, 201"), StatusCode(isNot: false, values: [.exact(200), .exact(201)]))
        XCTAssertEqual(parse("s 200,  201"), StatusCode(isNot: false, values: [.exact(200), .exact(201)]))
        XCTAssertEqual(parse("s 200,  201,"), StatusCode(isNot: false, values: [.exact(200), .exact(201)]))
        XCTAssertEqual(parse("s 200,  201, "), StatusCode(isNot: false, values: [.exact(200), .exact(201)]))
        XCTAssertEqual(parse("s 200,  201, 200-300"), StatusCode(isNot: false, values: [.exact(200), .exact(201), .closedRange(lowerBound: 200, upperBound: 300)]))

        // Not
        XCTAssertEqual(parse("s n 200"), StatusCode(isNot: true, values: [.exact(200)]))
        XCTAssertEqual(parse("s not 200"), StatusCode(isNot: true, values: [.exact(200)]))
        XCTAssertEqual(parse("s not200"), StatusCode(isNot: true, values: [.exact(200)]))
        XCTAssertEqual(parse("s !200"), StatusCode(isNot: true, values: [.exact(200)]))
        XCTAssertEqual(parse("s ! 200"), StatusCode(isNot: true, values: [.exact(200)]))
    }
}
