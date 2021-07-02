// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import CoreData
import XCTest
import Logging
@testable import Pulse
@testable import PulseCore

final class PersistentLogHandlerTests: XCTestCase {
    var tempDirectoryURL: URL!
    var storeURL: URL!

    var store: LoggerStore!
    var sut: PersistentLogHandler!

    var currentDate: Date = Date()

    override func setUp() {
        tempDirectoryURL = FileManager().temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true, attributes: [:])
        storeURL = tempDirectoryURL.appendingPathComponent("test-store")

        store = try! LoggerStore(storeURL: storeURL, options: [.create])
        store.makeCurrentDate = { [unowned self] in currentDate }

        sut = PersistentLogHandler(label: "test-hanlder", store: store)
    }

    override func tearDown() {
        store.destroyStores()
        try? FileManager.default.removeItem(at: tempDirectoryURL)
    }

    func testItPersistsLoggedMessages() throws {
        let deadlineExpectation = expectation(description: "Expected the deadline to be met.")

        let message1 = "This is a test message"
        let level1 = Logger.Level.info

        let message2 = "A second test message"
        let level2 = Logger.Level.critical

        let date = Date() - 200
        currentDate = date

        LoggerSession.startSession()
        let sessionID = LoggerSession.current.id

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            deadlineExpectation.fulfill()
        }

        waitForExpectations(timeout: 0.5)

        let persistedMessages = try store.allMessages()
        XCTAssertEqual(persistedMessages.count, 2)

        if persistedMessages.count >= 2 {
            let persistedMessage1 = persistedMessages[0]
            XCTAssertEqual(persistedMessage1.level, level1.rawValue)
            XCTAssertEqual(persistedMessage1.text, message1)
            XCTAssertEqual(persistedMessage1.createdAt, date)
            XCTAssertEqual(persistedMessage1.label, "test.logger.1")
            XCTAssertEqual(persistedMessage1.session, sessionID.uuidString)

            let persistedMessage2 = persistedMessages[1]
            XCTAssertEqual(persistedMessage2.level, level2.rawValue)
            XCTAssertEqual(persistedMessage2.text, message2)
            XCTAssertEqual(persistedMessage2.createdAt, date)
            XCTAssertEqual(persistedMessage2.label, "test.logger.2")
            XCTAssertEqual(persistedMessage2.session, sessionID.uuidString)
        }
    }

    func testStoresFileInformation() throws {
        // WHEN
        sut.log(level: .debug, message: "a", metadata: nil, file: "PersistenLogHandlerTests.swift", function: "testStoresFileInformation()", line: 86)
        flush(store: store)

        // THEN
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.file, "PersistenLogHandlerTests.swift")
        XCTAssertEqual(message.function, "testStoresFileInformation()")
        XCTAssertEqual(message.line, 86)
    }

    // MARK: Metadata

    func testStoringStringMetadata() throws {
        // WHEN
        sut.log(level: .debug, message: "request failed", metadata: ["system": "auth"])
        flush(store: store)

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
        flush(store: store)

        // THEN key-value metadata is stored
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.metadata.count, 1)
        let entry = try XCTUnwrap(message.metadata.first)
        XCTAssertEqual(entry.key, "system")
        XCTAssertEqual(entry.value, "foo")
    }

    func testQueryingMetadata() throws {
        // GIVEN
            sut.log(level: .debug, message: "a", metadata: ["system": "auth"])
            flush(store: store)

        // WHEN
        let request = NSFetchRequest<LoggerMessageEntity>(entityName: "LoggerMessageEntity")
        request.predicate = NSPredicate(format: "text == %@ AND SUBQUERY(metadata, $entry, $entry.key == %@ AND $entry.value == %@).@count > 0", "a", "system", "auth")
        let messages = try store.container.viewContext.fetch(request)

        // THEN
        let message = try XCTUnwrap(messages.first)
        XCTAssertEqual(message.metadata.count, 1)
        let entry = try XCTUnwrap(message.metadata.first)
        XCTAssertEqual(message.text, "a")
        XCTAssertEqual(entry.key, "system")
        XCTAssertEqual(entry.value, "auth")
    }
}

extension LogHandler {
    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata? = nil, file: String = #file, function: String = #function, line: UInt = #line) {
        self.log(level: level, message: message, metadata: metadata, source: "", file: file, function: function, line: line)
    }
}
