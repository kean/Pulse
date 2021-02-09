// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
import Foundation
import CoreData
@testable import Pulse
@testable import PulseCore

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
            let message = MessageEntity(context: context)
            message.createdAt = date.addingTimeInterval(-20)
            message.level = "debug"
            message.label = "default"
            message.session = "1"
            message.text = "message-01"
        }
        do {
            let message = MessageEntity(context: context)
            message.createdAt = date.addingTimeInterval(-5)
            message.level = "debug"
            message.label = "default"
            message.session = "1"
            message.text = "message-02"
        }

        try context.save()

        // WHEN
        store.sweep()
        flush(store: store)

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
        XCTAssertEqual(messages.count, 0, "Previously recoreded messages are going to be lost")

        store.destroyStores()
    }

    // MARK: - Remove Messages

    func testRemoveAllMessages() throws {
        // GIVEN
        try store.populate()
        let context = store.container.viewContext
        XCTAssertEqual(try context.fetch(MessageEntity.fetchRequest()).count, 1)
        XCTAssertEqual(try context.fetch(MetadataEntity.fetchRequest()).count, 1)

        // WHEN
        store.removeAllMessages()
        flush(store: store)

        // THEN both message and metadata are removed
        XCTAssertTrue(try context.fetch(MessageEntity.fetchRequest()).isEmpty)
        XCTAssertTrue(try context.fetch(MetadataEntity.fetchRequest()).isEmpty)
    }
}

private extension LoggerMessageStore {
    func populate() throws {
        let context = container.viewContext

        let message = MessageEntity(context: context)
        message.createdAt = Date()
        message.level = "debug"
        message.label = "default"
        message.session = "1"
        message.text = "Some message"
        message.metadata = [
            {
                let entity = MetadataEntity(context: context)
                entity.key = "system"
                entity.value = "application"
                return entity
            }()
        ]
        try context.save()
    }
}
