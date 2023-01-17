// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

@available(iOS 16, tvOS 16, *)
final class ConsoleSearchTokenTests: XCTestCase {
    func testSuggestedFilters() {
        let viewModel = ConsoleSearchViewModel(entities: try! LoggerStore.mock.allMessages(), store: .mock)

//        func suggestions(for string: String) -> [String] {
//            viewModel.makeSuggestedFilters(for: string)
//        }
//
//        XCTAssertEqual(viewModel.makeSuggestedFilters(for: "Status Code"), [
//
//        ])
    }

    func testStatusCodeFilter() throws {
        func parse(_ string: String) -> ConsoleSearchFilterStatusCode? {
            guard let filter = try? Parsers.filterStatusCode.parse(string),
                  case .statusCode(let filter) = filter.0 else {
                return nil
            }
            return filter
        }

        typealias StatusCode = ConsoleSearchFilterStatusCode

        XCTAssertNil(parse("bod 200"))

        XCTAssertEqual(parse("sttus"), StatusCode(values: []))

        XCTAssertEqual(parse("S"), StatusCode(values: []))
        XCTAssertEqual(parse("s"), StatusCode(values: []))
        XCTAssertEqual(parse("s "), StatusCode(values: []))
        XCTAssertEqual(parse("sta "), StatusCode(values: []))
        XCTAssertEqual(parse("status "), StatusCode(values: []))
        XCTAssertEqual(parse("stAtus "), StatusCode(values: []))
        XCTAssertEqual(parse("stAtus co"), StatusCode(values: []))
        XCTAssertEqual(parse("stAtus co:"), StatusCode(values: []))
        XCTAssertEqual(parse("stAtus codE:"), StatusCode(values: []))
        XCTAssertEqual(parse("status code: "), StatusCode(values: []))
        XCTAssertEqual(parse("status code:   "), StatusCode(values: []))

        // Reordering
        XCTAssertEqual(parse("code"), StatusCode(values: []))
        XCTAssertEqual(parse("code:"), StatusCode(values: []))
        XCTAssertEqual(parse("code sta:"), StatusCode(values: []))

        // Typo
        XCTAssertEqual(parse("sttus"), StatusCode(values: []))

        // Exact value
        XCTAssertEqual(parse("s200"), StatusCode(values: [.init(200)]))
        XCTAssertEqual(parse("s 200"), StatusCode(values: [.init(200)]))
        XCTAssertEqual(parse("code 200"), StatusCode(values: [.init(200)]))

        // Closed range
        XCTAssertEqual(parse("s 200-300"), StatusCode(values: [.init(.closed, lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200<=300"), StatusCode(values: [.init(.closed, lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200..300"), StatusCode(values: [.init(.closed, lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200...300"), StatusCode(values: [.init(.closed, lowerBound: 200, upperBound: 300)]))

        // Open range
        XCTAssertEqual(parse("s 200<300"), StatusCode(values: [.init(.open, lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200<300"), StatusCode(values: [.init(.open, lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200.<300"), StatusCode(values: [.init(.open, lowerBound: 200, upperBound: 300)]))
        XCTAssertEqual(parse("s 200..<300"), StatusCode(values: [.init(.open, lowerBound: 200, upperBound: 300)]))

        // List of values
        XCTAssertEqual(parse("s 200 201"), StatusCode(values: [.init(200), .init(201)]))
        XCTAssertEqual(parse("s 200, 201"), StatusCode(values: [.init(200), .init(201)]))
        XCTAssertEqual(parse("s 200,  201"), StatusCode(values: [.init(200), .init(201)]))
        XCTAssertEqual(parse("s 200,  201,"), StatusCode(values: [.init(200), .init(201)]))
        XCTAssertEqual(parse("s 200,  201, "), StatusCode(values: [.init(200), .init(201)]))
        XCTAssertEqual(parse("s 200,  201, 200-300"), StatusCode(values: [.init(200), .init(201), .init(.closed, lowerBound: 200, upperBound: 300)]))

        // False
        XCTAssertNil(parse("bod 200"))
    }

    // MARK: Values

    func testRangeOfInts() {
        func parse(_ string: String, in range: ClosedRange<Int> = Int.min...Int.max) -> ConsoleSearchRange<Int>? {
            try? Parsers.rangeOfInts(in: range).parse(string)
        }

        // Invididual value
        XCTAssertEqual(parse("200"), .init(200))
        XCTAssertEqual(parse("200"), .init(.closed, lowerBound: 200, upperBound: 200))

        // Closed range
        XCTAssertEqual(parse("200-300"), .init(.closed, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200–300"), .init(.closed, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200<=300"), .init(.closed, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200...300"), .init(.closed, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200..300"), .init(.closed, lowerBound: 200, upperBound: 300))

        // Open range
        XCTAssertEqual(parse("200<300"), .init(.open, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200.<300"), .init(.open, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200..<300"), .init(.open, lowerBound: 200, upperBound: 300))

        // With whitespace
        XCTAssertEqual(parse("200 - 300"), .init(.closed, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200   -  300"), .init(.closed, lowerBound: 200, upperBound: 300))
        XCTAssertEqual(parse("200 ..< 300"), .init(.open, lowerBound: 200, upperBound: 300))

        // With valid range
        XCTAssertEqual(parse("200", in: 100...500), .init(200))
        XCTAssertEqual(parse("100", in: 100...500), .init(100))
        XCTAssertEqual(parse("500", in: 100...500), .init(500))
        XCTAssertEqual(parse("100-500", in: 100...500), .init(.closed, lowerBound: 100, upperBound: 500))
        XCTAssertEqual(parse("500", in: 100...500), .init(500))

        XCTAssertNil(parse("-100", in: 100...500))
        XCTAssertNil(parse("0", in: 100...500))
        XCTAssertNil(parse("99", in: 100...500))
        XCTAssertNil(parse("501", in: 100...500))
        XCTAssertNil(parse("0-400", in: 100...500))

        // Invalid
        XCTAssertNil(parse("-10"))

        // Auto-completion
        XCTAssertEqual(parse("200*500"), .init(200))
    }

    func testListOf() {
        func parse(_ string: String) -> [ConsoleSearchRange<Int>] {
            (try? Parsers.listOf(Parsers.rangeOfInts).parse(string)) ?? []
        }

        XCTAssertEqual(parse("200"), [.init(200)])
        XCTAssertEqual(parse("200 300"), [.init(200), .init(300)])
        XCTAssertEqual(parse("200,300"), [.init(200), .init(300)])
        XCTAssertEqual(parse("200, 300"), [.init(200), .init(300)])
    }

    func testHttpMethod() {
        func parse(_ string: String) -> HTTPMethod? {
            try? Parsers.httpMethod.parse(string)
        }

        XCTAssertEqual(parse("G"), .get)
        XCTAssertEqual(parse("g"), .get)
        XCTAssertEqual(parse("GET"), .get)
        XCTAssertEqual(parse("get"), .get)
        XCTAssertEqual(parse("GeT"), .get)
    }

    // MARK: Helpers

    func testFilterName() {
        func parse(_ name: String, in string: String) -> Confidence {
            (try? Parsers.filterName(name).parse(string)) ?? Confidence(0)
        }

        func consume(_ name: String, in string: String) -> Substring {
            guard let (_, remainder) = try? Parsers.filterName(name).parse(string[...]) else {
                return string[...]
            }
            return remainder
        }

        XCTAssertEqual(parse("request", in: "status code"), 0.0)

        // One occurence instead of two is greater
        XCTAssertGreaterThan(parse("status code", in: "status code"), parse("status code", in: "status"))

        // Consume (important to cosume to figure out where the modifiers and arguments go
        XCTAssertEqual(consume("status code", in: "status code"), "")
        XCTAssertEqual(consume("status code", in: "status code:"), "")
        XCTAssertEqual(consume("status code", in: "status code: "), "")
        XCTAssertEqual(consume("status code", in: "status code : "), "")
        XCTAssertEqual(consume("status code", in: "code"), "")
        XCTAssertEqual(consume("status code", in: "status: "), "")
        XCTAssertEqual(consume("status code", in: "code: "), "")
        XCTAssertEqual(consume("status code", in: "status"), "")
        XCTAssertEqual(consume("host", in: "host example.com"), "example.com")
    }

    func testFuzzy() {
        XCTAssertGreaterThan("status".fuzzyMatch("stat"), "status".fuzzyMatch("sta"))
        XCTAssertGreaterThan("res".fuzzyMatch("response"), "res".fuzzyMatch("request"))
        XCTAssertGreaterThan("req".fuzzyMatch("request"), "req".fuzzyMatch("response"))
    }

    func testDistance() {
        XCTAssertEqual("".distance(to: "ab"), 2)
        XCTAssertEqual("ab".distance(to: ""), 2)
        XCTAssertEqual("".distance(to: ""), 0)

        XCTAssertEqual("a".distance(to: "a"), 0)
        XCTAssertEqual("a".distance(to: "ab"), 1)
        XCTAssertEqual("ba".distance(to: "ab"), 2)
        XCTAssertEqual("abc".distance(to: "ab"), 1)
        XCTAssertEqual("abcd".distance(to: "abd"), 1)
    }
}
