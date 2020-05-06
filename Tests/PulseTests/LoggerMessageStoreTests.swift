// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
@testable import Pulse

final class LoggerMessageStoreTests: XCTestCase {
    func testShortLivedMessages() throws {
        let deadlineExpectation = expectation(description: "Expected the deadline to be met.")
        let deletionExpectation = expectation(description: "Expected the deletion deadline to be met.")

        let shortLivedStore = LoggerMessageStore(name: "test", logsExpirationInterval: 0.1)
        shortLivedStore.removeAllMessages()

        let logger = Logger(label: "test", factory: { PersistentLogHandler(label: $0, store: shortLivedStore) })
        logger.warning("warning")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deadlineExpectation.fulfill()
        }

        wait(for: [deadlineExpectation], timeout: 0.5)

        XCTAssertEqual(try shortLivedStore.allMessages().count, 1)

        shortLivedStore.sweep()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deletionExpectation.fulfill()
        }

        wait(for: [deletionExpectation], timeout: 0.5)

        XCTAssert(try shortLivedStore.allMessages().isEmpty)
    }

    func testLongLivedMessages() throws {
        let deadlineExpectation = expectation(description: "Expected the deadline to be met.")
        let deletionExpectation = expectation(description: "Expected the deletion deadline to be met.")

        let longLivedStore = LoggerMessageStore(name: "test")
        longLivedStore.removeAllMessages()

        let logger = Logger(label: "test", factory: { PersistentLogHandler(label: $0, store: longLivedStore) })
        logger.warning("warning")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deadlineExpectation.fulfill()
        }

        wait(for: [deadlineExpectation], timeout: 0.5)

        XCTAssertEqual(try longLivedStore.allMessages().count, 1)

        longLivedStore.sweep()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deletionExpectation.fulfill()
        }

        wait(for: [deletionExpectation], timeout: 0.5)

        XCTAssertEqual(try longLivedStore.allMessages().count, 1)
    }
}
