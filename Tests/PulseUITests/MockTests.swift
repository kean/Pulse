// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

#if DEBUG
final class MockTests: XCTestCase {
    func testMakingEntity() {
        let entity = LoggerStore.preview.entity(for: .login)
        XCTAssertEqual(entity.url, "https://github.com/login?scopes=profile,repos")
    }
}
#endif
