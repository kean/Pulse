// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import PulseCore
@testable import PulseUI

final class MockTests: XCTestCase {
    func testMakingEntity() async {
        let entity = LoggerStore.preview.entity(for: .login)
        XCTAssertEqual(entity.url, "https://github.com/login?username=kean&password=nope")
    }
}
