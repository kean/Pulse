import CoreData
import XCTest
import Logging
@testable import Pulse

final class PersistentLogHandlerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        LoggerMessageStore.default.removeAllMessages()
    }

    func testItStoresMetadata() throws {
        let id = UUID()

        var logger = Logger(label: "test.logger", factory: { PersistentLogHandler(label: $0) })
        logger[metadataKey: "id"] = "\(id)"

        XCTAssertEqual(logger[metadataKey: "id"], "\(id)")
    }

    func testItPersistsLoggedMessages() throws {
        let deadlineExpectation = expectation(description: "Expected the deadline to be met.")

        let message1 = "This is a test message"
        let level1 = Logger.Level.info

        let message2 = "A second test message"
        let level2 = Logger.Level.critical

        let date = Date()
        let sessionID = PersistentLogHandler.startSession()

        LoggingSystem.bootstrap {
            MultiplexLogHandler([
                PersistentLogHandler(label: $0, store: LoggerMessageStore.default, makeCurrentDate: { date }),
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

        let persistedMessages = try LoggerMessageStore.default.allMessages()
        XCTAssertEqual(persistedMessages.count, 2)

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
