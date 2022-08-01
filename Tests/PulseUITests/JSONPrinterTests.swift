// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import PulseCore
@testable import PulseUI

final class JSONPrinterTests: XCTestCase {
    func testTypMismatchError() throws {
        // GIVEN
        let json = try JSONSerialization.jsonObject(with: MockJSON.allPossibleValues)
        let error = generateTypeMismatchError()

        // WHEN
        let renderer = AttributedStringJSONRenderer(fontSize: 12, lineHeight: 15)
        let printer = JSONPrinter(renderer: renderer)
        printer.render(json: json, error: error)
        let string = renderer.make()

        // THEN
        let range = NSRange(try XCTUnwrap(string.string.firstRange(of: "56")), in: string.string)
        var effectiveRange: NSRange = .init(location: 0, length: 1)
        let attributes = string.attributes(at: range.location, effectiveRange: &effectiveRange)
        XCTAssertNotNil(attributes[.backgroundColor])
        XCTAssertEqual(effectiveRange, NSRange(location: 103, length: 2))
    }
}


private func generateTypeMismatchError() -> NetworkLoggerDecodingError? {
    struct JSON: Decodable {
        let actors: [Actor]

        struct Actor: Decodable {
            let age: String
        }
    }
    do {
        _ = try JSONDecoder().decode(JSON.self, from: MockJSON.allPossibleValues)
        return nil
    } catch {
        return NetworkLoggerDecodingError(error as! DecodingError)
    }
}
