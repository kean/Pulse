// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
@testable import Pulse

final class LoggerMessageStoreTests: XCTestCase {
    var tempDirectoryURL: URL!
    var storeURL: URL!

    var store: LoggerMessageStore!

    override func setUp() {
        tempDirectoryURL = FileManager().temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: [:])
        storeURL = tempDirectoryURL.appendingPathComponent("test-store")

        store = LoggerMessageStore(storeURL: storeURL)
    }

    override func tearDown() {
        store.destroyStores()
        try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    // MARK: - Init

    func testInitStoreWithURL() throws {
        // GIVEN
        try store.populate()
        XCTAssertEqual(try store.allMessages().count, 1)

        store.removeStores()

        // WHEN loading the store with the same url
        store = LoggerMessageStore(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try store.allMessages().count, 1)
    }

    // MARK: - Expiration

    func testExpiredMessagesAreRemoved() throws {
        // GIVEN
        store.logsExpirationInterval = 10
        let date = Date()
        store.makeCurrentDate = { date }

        let context = store.container.viewContext

        do {
            let message = LoggerMessage(context: context)
            message.createdAt = date.addingTimeInterval(-20)
            message.level = "debug"
            message.label = "default"
            message.session = "1"
            message.text = "message-01"
        }
        do {
            let message = LoggerMessage(context: context)
            message.createdAt = date.addingTimeInterval(-5)
            message.level = "debug"
            message.label = "default"
            message.session = "1"
            message.text = "message-02"
        }

        try context.save()

        // WHEN
        store.sweep()
        let sweepCompleted = expectation(description: "Sweep Completed")
        store.backgroundContext.perform {
            sweepCompleted.fulfill()
        }
        wait(for: [sweepCompleted], timeout: 5)

        // THEN expired message was removed
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.text, "message-02")
    }

    // MARK: - Migration

    func testMigrationFromVersion0_2ToLatest() throws {
        // GIVEN store created with the model from Pulse 0.2
        let storeURL = tempDirectoryURL.appendingPathComponent("test-migration-from-0-2")
        try Resources.outdatedDatabase.write(to: storeURL)

        // WHEN migrating to the store with the latest model
        let store = LoggerMessageStore(storeURL: storeURL)

        // THEN automatic migration is performed and new field are populated with
        // empty values
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 6, "Expected all previously recorded messasges to persist")
        XCTAssertEqual(messages.first?.text, "UIApplication.didFinishLaunching", "Expected text to be preserved")
        XCTAssertEqual(messages.first?.label, "", "Expected new label field to be populated with an empty value")

        store.destroyStores()
    }
}

private extension LoggerMessageStore {
    func populate() throws {
        let context = container.viewContext

        let message = LoggerMessage(context: context)
        message.createdAt = Date()
        message.level = "debug"
        message.label = "default"
        message.session = "1"
        message.text = "Some message"
        try context.save()
    }
}

private extension LoggerMessageStore {
    func removeStores() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
    }

    func destroyStores() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.destroyPersistentStore(at: store.url!, ofType: NSSQLiteStoreType, options: [:])
        }
    }
}
