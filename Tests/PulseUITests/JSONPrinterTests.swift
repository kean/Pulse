// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

#if DEBUG
#if !os(watchOS)
final class JSONPrinterTests: XCTestCase {
    func testTypMismatchError() throws {
        // GIVEN
        let json = try JSONSerialization.jsonObject(with: MockJSON.allPossibleValues)
        let error = generateTypeMismatchError()

        // WHEN
        let renderer = TextRendererJSON()
        let string = renderer.render(json: json, error: error)

        // THEN
        let range = NSRange(try XCTUnwrap(string.string.firstRange(of: "56")), in: string.string)
        var effectiveRange: NSRange = .init(location: 0, length: 1)
        let attributes = string.attributes(at: range.location, effectiveRange: &effectiveRange)
        XCTAssertNotNil(attributes[.backgroundColor])
        XCTAssertEqual(effectiveRange, NSRange(location: 103, length: 2))
    }
}


private func generateTypeMismatchError() -> NetworkLogger.DecodingError? {
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
        return NetworkLogger.DecodingError(error as! DecodingError)
    }
}
#endif
#endif
