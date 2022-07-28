// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import PulseCore
@testable import PulseUI

final class ConsoleViewModelTests: XCTestCase {
    func testExample() async {
        let entity = LoggerStore.preview.makeEntity(for: .login)
        XCTAssertEqual(entity.url, "https://github.com/login")
    }
}
