// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
import Foundation
import CoreData
@testable import Pulse

final class LoggerMessageStoreTests: XCTestCase {
    var tempDir: TempDirectory!

    override func setUp() {
        super.setUp()

        tempDir = try! TempDirectory()
    }

    override func tearDown() {
        super.tearDown()

        try! tempDir.destroy()
    }

    func testInit() {
        // WHEN
        let storeURL = tempDir.file(named: "temp-store")
        let store = LoggerMessageStore2(storeURL: storeURL)

        // THEN
        XCTAssertNil(store.error)
    }
}
