// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import XCTest
import Logging
import Combine
@testable import PulseLogHandler
@testable import Pulse

final class PersistentLogHandlerTests: XCTestCase {
    var tempDirectoryURL: URL!
    var storeURL: URL!

    var store: LoggerStore!
    var sut: PersistentLogHandler!

    var currentDate: Date = Date()

    override func setUp() {
        tempDirectoryURL = FileManager().temporaryDirectory.appending(directory: UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: [:])
        storeURL = tempDirectoryURL.appending(filename: "test-store")

        var configuration = LoggerStore.Configuration()
        configuration.makeCurrentDate = { [unowned self] in currentDate }
        store = try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous], configuration: configuration)

        sut = PersistentLogHandler(label: "test-hanlder", store: store)
    }

    override func tearDown() {
        store.destroyStores()
        try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    func testItPersistsLoggedMessages() throws {
        let message1 = "This is a test message"
        let level1 = Logger.Level.info

        let message2 = "A second test message"
        let level2 = Logger.Level.critical

        let date = Date() - 200
        currentDate = date

        LoggerStore.Session.startSession()
        let sessionID = LoggerStore.Session.current.id

        LoggingSystem.bootstrap {
            MultiplexLogHandler([
                PersistentLogHandler(label: $0, store: self.store),
                StreamLogHandler.standardOutput(label: $0)
            ])
        }

        var logger1 = Logger(label: "test.logger.1")
        logger1[metadataKey: "test-uuid"] = "\(UUID())"
        logger1.log(level: level1, "\(message1)")

        let logger2 = Logger(label: "test.logger.2")
        logger2.log(level: level2, "\(message2)", metadata: ["foo": "bar"])

        let persistedMessages = try store.allMessages()
        guard persistedMessages.count == 2 else {
            return XCTFail("Unexpected number of messages stored")
        }

        let persistedMessage1 = try XCTUnwrap(persistedMessages.first { $0.label.name == "test.logger.1" })
        XCTAssertEqual(persistedMessage1.text, message1)
        XCTAssertEqual(persistedMessage1.createdAt, date)
        XCTAssertEqual(persistedMessage1.session, sessionID)

        let persistedMessage2 = try XCTUnwrap(persistedMessages.first { $0.label.name == "test.logger.2" })
        XCTAssertEqual(persistedMessage2.text, message2)
        XCTAssertEqual(persistedMessage2.createdAt, date)
        XCTAssertEqual(persistedMessage2.session, sessionID)
    }

    func testStoresFileInformation() throws {
        // WHEN
        sut.log(level: .debug, message: "a", metadata: nil, file: "PersistenLogHandlerTests.swift", function: "testStoresFileInformation()", line: 86)

        // THEN
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.file, "PersistenLogHandlerTests.swift")
        XCTAssertEqual(message.function, "testStoresFileInformation()")
        XCTAssertEqual(message.line, 86)
    }

    func testStoresFilename() throws {
        // WHEN
        sut.log(level: .debug, message: "a", metadata: nil, file: #file, function: #function, line: 86)

        // THEN
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.file, "PersistenLogHandlerTests.swift")
        XCTAssertEqual(message.function, "testStoresFilename()")
        XCTAssertEqual(message.line, 86)
    }

    // MARK: Metadata

    func testStoringStringMetadata() throws {
        // WHEN
        sut.log(level: .debug, message: "request failed", metadata: ["system": "auth"])

        // THEN key-value metadata is stored
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.metadata.count, 1)
        let entry = try XCTUnwrap(message.metadata.first)
        XCTAssertEqual(entry.key, "system")
        XCTAssertEqual(entry.value, "auth")
    }

    func testStoringStringConvertibleMetadata() throws {
        // GIVEN
        struct Foo: CustomStringConvertible {
            var description: String {
                return "foo"
            }
        }

        // WHEN
        sut.log(level: .debug, message: "a", metadata: ["system": .stringConvertible(Foo())])

        // THEN key-value metadata is stored
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.metadata.count, 1)
        let entry = try XCTUnwrap(message.metadata.first)
        XCTAssertEqual(entry.key, "system")
        XCTAssertEqual(entry.value, "foo")
    }
}

extension LogHandler {
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: level, message: message, metadata: metadata, source: "", file: file, function: function, line: line)
    }
}

extension LoggerStore {
    func destroyStores() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.destroyPersistentStore(at: store.url!, ofType: NSSQLiteStoreType, options: [:])
        }
    }
}
