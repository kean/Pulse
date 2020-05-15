// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
import Foundation
import CoreData
@testable import Pulse

final class LoggerMessageStore2Tests: XCTestCase {
    var tempDir: TempDirectory!
    var storeURL: URL!
    var store: LoggerMessageStore2!

    override func setUp() {
        super.setUp()

        tempDir = try! TempDirectory()
        storeURL = tempDir.file(named: "test-store")
        store = LoggerMessageStore2(storeURL: storeURL)
    }

    override func tearDown() {
        super.tearDown()

        try! tempDir.destroy()
    }

    // MARK: - Init

    func testInitStoreWithURL() throws {
        // GIVEN
        try store.populate()
        XCTAssertEqual(try store.allMessages().count, 1)
        store.close()

        // WHEN loading the store with the same url
        store = LoggerMessageStore2(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try store.allMessages().count, 1)
    }

    // MARK: - Expiration

    #warning("TODO: reimplement")
    func testExpiredMessagesAreRemoved() throws {
        // GIVEN
        store.logsExpirationInterval = 10
        let date = Date()
        store.makeCurrentDate = { date }

        try store.insert(messages: [
            MessageItem(
                id: 1,
                createdAt: date.addingTimeInterval(-20),
                level: "debug",
                label: "default",
                session: "1",
                text: "message-01",
                metadata: [],
                file: "File",
                function: "Function",
                line: 10
            ),
            MessageItem(
                 id: 2,
                 createdAt: date.addingTimeInterval(-5),
                 level: "debug",
                 label: "default",
                 session: "1",
                 text: "message-02",
                 metadata: [],
                 file: "File",
                 function: "Function",
                 line: 10
             )
        ])


        // WHEN
        try store.sweep()

        // THEN expired message was removed
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.id, 2)
        XCTAssertEqual(messages.first?.text, "message-02")
    }

    // MARK: - Remove Messages

//    func testRemoveAllMessages() throws {
//        // GIVEN
//        try store.populate()
//        XCTAssertEqual(try context.fetch(MessageEntity.fetchRequest()).count, 1)
//        XCTAssertEqual(try context.fetch(MetadataEntity.fetchRequest()).count, 1)
//
//        // WHEN
//        store.removeAllMessages()
//        flush(store: store)
//
//        // THEN both message and metadata are removed
//        XCTAssertTrue(try context.fetch(MessageEntity.fetchRequest()).isEmpty)
//        XCTAssertTrue(try context.fetch(MetadataEntity.fetchRequest()).isEmpty)
//    }
}

private extension LoggerMessageStore2 {
    func populate() throws {
        let message = MessageItem(
            id: 0,
            createdAt: Date(),
            level: "debug",
            label: "default",
            session: "1",
            text: "Some message",
            metadata: [MetadataItem(key: "system", value: "application")],
            file: "LoggerMessageStoreTests.swift",
            function: "populate()",
            line: 131
        )

        try insert(messages: [message])
    }
}

