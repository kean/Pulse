// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
import Foundation
import CoreData
@testable import Pulse
@testable import PulseCore

final class LoggerStoreTests: XCTestCase {
    var tempDirectoryURL: URL!
    var storeURL: URL!

    var store: LoggerStore!

    override func setUp() {
        super.setUp()

        tempDirectoryURL = FileManager().temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: [:])
        storeURL = tempDirectoryURL.appendingPathComponent("test-store")

        store = try! LoggerStore(storeURL: storeURL, options: [.create])
    }

    override func tearDown() {
        super.tearDown()

        store.destroyStores()

        try? FileManager.default.removeItem(at: tempDirectoryURL)
        try? FileManager.default.removeItem(at: URL.temp)
        try? FileManager.default.removeItem(at: URL.logs)
    }

    // MARK: - Init

    func testInitStoreMissing() throws {
        // GIVEN
        let storeURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)

        // WHEN/THEN
        XCTAssertThrowsError(try LoggerStore(storeURL: storeURL))
    }

    func testInitCreateStoreURL() throws {
        // GIVEN
        let storeURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
        let options: LoggerStore.Options = [.create]

        // WHEN
        let firstStore = try LoggerStore(storeURL: storeURL, options: options)
        try firstStore.populate()

        let secondStore = try LoggerStore(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try secondStore.allMessages().count, 1)

        // CLEANUP
        firstStore.destroyStores()
        secondStore.destroyStores()
    }

    func testInitCreateStoreIntermediateDirectoryMissing() throws {
        // GIVEN
        let storeURL = tempDirectoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: false) // Missing directory
            .appendingPathComponent(UUID().uuidString)
        let options: LoggerStore.Options = [.create]

        // WHEN/THEN
        XCTAssertThrowsError(try LoggerStore(storeURL: storeURL, options: options))
    }

    func testInitStoreWithURL() throws {
        // GIVEN
        try store.populate()
        XCTAssertEqual(try store.allMessages().count, 1)

        let originalStore = store
        store.removeStores()

        // WHEN loading the store with the same url
        store = try LoggerStore(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try store.allMessages().count, 1)

        // CLEANUP
        originalStore?.destroyStores()
    }

    func testInitWithArchiveURL() throws {
        // GIVEN
        let originalURL = try XCTUnwrap(Bundle.module.url(forResource: "logs-2021-03-18_21-22", withExtension: "pulse"))
        let storeURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: originalURL, to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))

        // THEN
        XCTAssertEqual(try store.allMessages().count, 23)
        XCTAssertEqual(try store.allNetworkRequests().count, 4)

        store.destroyStores()
    }

    func testInitWithArchiveURLNoExtension() throws {
        // GIVEN
        let storeURL = try XCTUnwrap(Bundle.module.url(forResource: "logs-2021-03-18_21-22", withExtension: "pulse"))

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))

        // THEN
        XCTAssertEqual(try store.allMessages().count, 23)
        XCTAssertEqual(try store.allNetworkRequests().count, 4)
    }

    func testInitWithPackageURL() throws {
        // GIVEN
        let storeURL = try XCTUnwrap(Bundle.module.url(forResource: "logs-package", withExtension: "pulse"))

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))

        // THEN
        XCTAssertEqual(try store.allMessages().count, 23)
        XCTAssertEqual(try store.allNetworkRequests().count, 4)
    }

    func testInitWithPackageURLNoExtension() throws {
        // GIVEN
        let originalURL = try XCTUnwrap(Bundle.module.url(forResource: "logs-package", withExtension: "pulse"))
        let storeURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: originalURL, to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))

        // THEN
        XCTAssertEqual(try store.allMessages().count, 23)
        XCTAssertEqual(try store.allNetworkRequests().count, 4)

        store.destroyStores()
    }

    // MARK: - Copy (Directory)

    func testCopyDirectory() throws {
        // GIVEN
        populate2(store: store)

        let copyURL = tempDirectoryURL.appendingPathComponent("copy.pulse")

        // WHEN
        let manifest = try store.copy(to: copyURL)

        // THEN
        // XCTAssertEqual(manifest.messagesSize, 73728)
        // XCTAssertEqual(manifest.blobsSize, 21195)
        XCTAssertEqual(manifest.messageCount, 19)
        XCTAssertEqual(manifest.requestCount, 3)

        store.removeStores()

        // THEN
        let copy = try LoggerStore(storeURL: copyURL)
        XCTAssertEqual(try copy.allMessages().count, 19)
        XCTAssertEqual(try copy.allNetworkRequests().count, 3)
        copy.destroyStores()
    }

    func testCopyToNonExistingFolder() throws {
        // GIVEN
        populate2(store: store)

        let invalidURL = tempDirectoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("copy.pulse")

        // WHEN/THEN
        XCTAssertThrowsError(try store.copy(to: invalidURL))
    }

    func testCopyButFileExists() throws {
        // GIVEN
        populate2(store: store)

        let copyURL = tempDirectoryURL
            .appendingPathComponent("copy.pulse")

        try store.copy(to: copyURL)

        // WHEN/THEN
        XCTAssertThrowsError(try store.copy(to: copyURL))
    }

    func testCreateMultipleCopies() throws {
        // GIVEN
        populate2(store: store)

        let copyURL1 = self.storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("copy.pulse")

        let copyURL2 = self.storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("copy2.pulse")

        // WHEN
        let manifest1 = try store.copy(to: copyURL1)
        let manifest2 = try store.copy(to: copyURL2)

        // THEN
        // XCTAssertEqual(manifest.messagesSize, 73728)
        // XCTAssertEqual(manifest.blobsSize, 21195)
        XCTAssertEqual(manifest1.messageCount, 19)
        XCTAssertEqual(manifest1.requestCount, 3)
        XCTAssertEqual(manifest2.messageCount, 19)
        XCTAssertEqual(manifest2.requestCount, 3)
        XCTAssertNotEqual(manifest1.id, manifest2.id)
    }

    // MARK: - Copy (File)

    func testCopyFile() throws {
        // GIVEN
        let storeURL = try XCTUnwrap(Bundle.module.url(forResource: "logs-2021-03-18_21-22", withExtension: "pulse"))
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        let copyURL = tempDirectoryURL.appendingPathComponent("copy.pulse")

        // WHEN
        let manifest = try store.copy(to: copyURL)

        // THEN
        // XCTAssertEqual(manifest.messagesSize, 73728)
        // XCTAssertEqual(manifest.blobsSize, 21195)
        XCTAssertEqual(manifest.messageCount, 23)
        XCTAssertEqual(manifest.requestCount, 4)

        // THEN
        let copy = try LoggerStore(storeURL: copyURL)
        XCTAssertEqual(try copy.allMessages().count, 23)
        XCTAssertEqual(try copy.allNetworkRequests().count, 4)
        copy.destroyStores()
    }

    // MARK: - File (Readonly)

    // TODO: this type of store is no longer immuatble
    func _testOpenFileDatabaseImmutable() throws {
        // GIVEN
        let storeURL = try XCTUnwrap(Bundle.module.url(forResource: "logs-2021-03-18_21-22", withExtension: "pulse"))
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        XCTAssertEqual(try store.allMessages().count, 23)

        // WHEN/THEN
        store.storeMessage(label: "test", level: .info, message: "test", metadata: nil)
        flush(store: store)

        // THEN nothing is written
        XCTAssertEqual(try store.allMessages().count, 23)

        let storeCopy = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        XCTAssertEqual(try storeCopy.allMessages().count, 23)
    }

    // MARK: - Expiration

    func testSizeLimit() throws {
        let limitBefore = LoggerStore.databaseSizeLimit
        defer { LoggerStore.databaseSizeLimit = limitBefore }

        // GIVEN
        let context = store.container.viewContext

        let date = Date()
        for index in 1...500 {
            let message = LoggerMessageEntity(store: store)
            message.createdAt = date + TimeInterval(index)
            message.level = "debug"
            message.label = "default"
            message.session = "1"
            message.text = "\(index)"
            if index % 50 == 0 {
                let metadata = LoggerMetadataEntity(store: store)
                metadata.key = "key"
                metadata.value = "\(index)"

                message.metadata = [metadata]
            }
        }

        try context.save()

        let copyURL = tempDirectoryURL.appendingFilename(UUID().uuidString).appendingPathExtension("pulse")
        try store.copy(to: copyURL)

        // SANITY
        var messages = try store.allMessages()
        XCTAssertEqual(messages.count, 500)
        XCTAssertEqual(messages.last?.text, "500")

        XCTAssertEqual(try context.fetch(LoggerMessageEntity.fetchRequest()).count, 500)
        XCTAssertEqual(try context.fetch(LoggerMetadataEntity.fetchRequest()).count, 10)

        // WHEN
        LoggerStore.databaseSizeLimit = 5_000 // In reality this is always going to be ignored
        store.sweep()
        flush(store: store)

        // THEN
        let copyURL2 = tempDirectoryURL.appendingFilename(UUID().uuidString).appendingPathExtension("pulse")
        try store.copy(to: copyURL2)

        // THEN unwanted messages were removed
        messages = try store.allMessages()
        XCTAssertEqual(messages.count, 251)
        XCTAssertEqual(messages.last?.text, "500") // Latest stored

        // THEN metadata and other relationships also removed
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.fetchRequest()).count, 251)
        XCTAssertEqual(try context.fetch(LoggerMetadataEntity.fetchRequest()).count, 6)
    }

    // MARK: - Migration

    func testMigrationFromVersion0_2ToLatest() throws {
        // GIVEN store created with the model from Pulse 0.2
        let storeURL = tempDirectoryURL
            .appendingDirectory(UUID().uuidString)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true, attributes: nil)
        let databaseURL = storeURL
            .appendingFilename("logs.sqlite")
        try Resources.outdatedDatabase.write(to: databaseURL)

        // WHEN migrating to the store with the latest model
        let store = try LoggerStore(storeURL: storeURL)

        // THEN automatic migration is performed and new field are populated with
        // empty values
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 0, "Previously recoreded messages are going to be lost")

        // WHEN
        try store.populate()

        // THEN can write new messages
        XCTAssertEqual(try store.allMessages().count, 1)

        store.destroyStores()
    }

    // MARK: - Remove Messages

    func testRemoveAllMessages() throws {
        // GIVEN
        populate2(store: store)
        store.storeMessage(label: "with meta", level: .debug, message: "test", metadata: ["hey": .string("this is meta yo")], file: #file, function: #function, line: #line)
        flush(store: store)

        let context = store.container.viewContext
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.fetchRequest()).count, 20)
        XCTAssertEqual(try context.fetch(LoggerMetadataEntity.fetchRequest()).count, 1)
        XCTAssertEqual(try context.fetch(LoggerNetworkRequestEntity.fetchRequest()).count, 3)
        XCTAssertEqual(try context.fetch(LoggerNetworkRequestDetailsEntity.fetchRequest()).count, 3)

        // WHEN
        store.removeAll()

        let expectation = self.expectation(description: "test")
        store.backgroundContext.perform {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3)

        // THEN both message and metadata are removed
        XCTAssertTrue(try context.fetch(LoggerMessageEntity.fetchRequest()).isEmpty)
        XCTAssertTrue(try context.fetch(LoggerMetadataEntity.fetchRequest()).isEmpty)
        XCTAssertTrue(try context.fetch(LoggerNetworkRequestEntity.fetchRequest()).isEmpty)
        XCTAssertTrue(try context.fetch(LoggerNetworkRequestDetailsEntity.fetchRequest()).isEmpty)
    }
}

private extension LoggerStore {
    func populate() throws {
        let context = container.viewContext

        let message = LoggerMessageEntity(store: store)
        message.createdAt = Date()
        message.level = "debug"
        message.label = "default"
        message.session = "1"
        message.text = "Some message"
        message.metadata = [
            {
                let entity = LoggerMetadataEntity(store: store)
                entity.key = "system"
                entity.value = "application"
                return entity
            }()
        ]

        try context.save()
    }
}
