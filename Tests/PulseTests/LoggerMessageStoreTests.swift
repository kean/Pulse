// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
@testable import Pulse

final class LoggerMessageStoreTests: XCTestCase {
    // MARK: - Init

    func testInitStoreWithURL() throws {
        // GIVEN
        let storeURL = FileManager().temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LoggerMessageStore(storeURL: storeURL)

        let context = store.container.viewContext

        let message = LoggerMessage(context: context)
        message.createdAt = Date()
        message.level = "debug"
        message.label = "default"
        message.session = "1"
        message.text = "Some message"
        try context.save()

        XCTAssertEqual(try store.allMessages().count, 1)

        // WHEN loading the store with the same url
        let newStore = LoggerMessageStore(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try newStore.allMessages().count, 1)
    }

    func testShortLivedMessages() throws {
        let deadlineExpectation = expectation(description: "Expected the deadline to be met.")
        let deletionExpectation = expectation(description: "Expected the deletion deadline to be met.")

        let shortLivedStore = LoggerMessageStore(name: "test")
        shortLivedStore.logsExpirationInterval = 0.1
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

    // MARK: - Migration

    func testMigrationFromVersion0_2ToLatest() throws {
        // GIVEN store created with the model from Pulse 0.2
        let storeURL = FileManager().temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Resources.outdatedDatabase.write(to: storeURL)

        // WHEN migrating to the store with the latest model
        let store = LoggerMessageStore(storeURL: storeURL)

        // THEN automatic migration is performed and new field are populated with
        // empty values
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 6, "Expected all previously recorded messasges to persist")
        XCTAssertEqual(messages.first?.text, "UIApplication.didFinishLaunching", "Expected text to be preserved")
        XCTAssertEqual(messages.first?.label, "", "Expected new label field to be populated with an empty value")

        try? FileManager.default.removeItem(at: storeURL)
    }
}
