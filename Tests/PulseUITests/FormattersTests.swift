// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

final class FormattersTests: XCTestCase {
    func testCountFormatter() throws {
        XCTAssertEqual(CountFormatter.string(from: 10), "10")
        XCTAssertEqual(CountFormatter.string(from: 999), "999")
        XCTAssertEqual(CountFormatter.string(from: 1000), "1k")
        XCTAssertEqual(CountFormatter.string(from: 1049), "1k")
        XCTAssertEqual(CountFormatter.string(from: 1099), "1.1k")
        XCTAssertEqual(CountFormatter.string(from: 1100), "1.1k")
    }
}
