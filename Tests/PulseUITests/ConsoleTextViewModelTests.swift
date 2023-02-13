// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

@available(macOS 13, *)
final class ConsoleTextViewModelTests: ConsoleTestCase {
    var sut: ConsoleTextViewModel!

    var criteria: ConsoleSearchCriteriaViewModel!
    var router: ConsoleRouter!
    var textView: NSTextView!

    var string: String { sut.text.textStorage.string }

    override func setUp() {
        super.setUp()

        store.removeAll()

        reset()
    }

    func reset() {
        criteria = ConsoleSearchCriteriaViewModel(criteria: .init(), index: .init(store: store))
        router = ConsoleRouter()
        textView = NSTextView()

        sut = ConsoleTextViewModel(store: store, criteria: criteria, router: router)
        sut.text.textView = textView
        sut.isViewVisible = true
    }

    func testInitialTextIsRendered() {
        // GIVEN
        store.storeMessage(label: "test-label", level: .debug, message: "test-text")

        // WHEN
        reset()

        // THEN
        XCTAssertNotNil(string.wholeMatch(of: /(.*?) · Test-Label · test-text\n/), string)
    }

    func testInsertedMessageRendered() {
        let expectation = self.expectation(description: "text-changes")
        sut.didRefresh = { expectation.fulfill() }

        // WHEN
        store.storeMessage(label: "test-label", level: .debug, message: "test-text")

        // THEN
        wait(for: [expectation], timeout: 2)
        XCTAssertNotNil(string.wholeMatch(of: /(.*?) · Test-Label · test-text\n/), string)
    }

    func testInsertedPendingTaskRendered() {
        // GIVEN
        let textInsertedExpectation = self.expectation(description: "textInsertedExpectation")
        sut.didRefresh = { textInsertedExpectation.fulfill() }

        // GIVEN
        let logger = NetworkLogger(store: store)

        // WHEN
        let url = URL(string: "https://example.com/api")!
        let task = URLSession.shared.dataTask(with: URLRequest(url: url))
        logger.logTaskCreated(task)

        // THEN
        wait(for: [textInsertedExpectation], timeout: 2)
        XCTAssertNotNil(string.wholeMatch(of: /(.*?) · Pending · GET https:\/\/example.com\/api\n/), string)

        // GIVEN
        let textUpdatedEpectation = self.expectation(description: "textUpdatedxpectation")
        sut.didRefresh = { textUpdatedEpectation.fulfill() }

        // WHEN
        task.setValue(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil), forKeyPath: "response")
        logger.logTask(task, didCompleteWithError: nil)

        // THEN
        wait(for: [textUpdatedEpectation], timeout: 2)
        XCTAssertNotNil(string.wholeMatch(of: /(.*?) · 200 OK · GET https:\/\/example.com\/api\n/), string)
    }

    func testDetailsShown() throws {
        // GIVEN
        let urlRequest = URLRequest(url: URL(string: "https://example.com/api")!)
        store.storeRequest(urlRequest, response: nil, error: nil, data: nil)
        let entity = try XCTUnwrap(store.allTasks().first)
        let url = entity.objectID.uriRepresentation()

        // WHEN
        XCTAssertTrue(sut.onLinkTapped(url))

        // THEN
        XCTAssertEqual(router.selection, .entity(entity.objectID))
    }
}

#endif
