// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
@testable import PulseCore

final class URLSessionProxyTests: XCTestCase {
    let directory = TemporaryDirectory()
    var store: LoggerStore!
    var logger: NetworkLogger!

    override func setUp() {
        super.setUp()

        let storeURL = directory.url.appendingPathComponent("logs.pulse", isDirectory: false)
        store = try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous])
        logger = NetworkLogger(store: store)

        Experimental.URLSessionProxy.shared.logger = logger
        Experimental.URLSessionProxy.shared.isEnabled = true
    }

    override func tearDown() {
        super.tearDown()

        store.destroyStores()

        directory.remove()

        Experimental.URLSessionProxy.shared.isEnabled = false
    }

    func testRecordSuccess() throws {
        // WHEN
        let dataURL = directory.url.appendingPathComponent("logs-archive-v2.pulse")
        try Resources.pulseArchive.write(to: dataURL)
        let didComplete = self.expectation(description: "TaskCompleted")
        let dataTask = URLSession.shared.dataTask(with: dataURL) { _, _, _ in
            didComplete.fulfill()
        }
        dataTask.resume()
        wait(for: [didComplete], timeout: 5)

        // RECORD
        let requests = try store.allNetworkRequests()
        let request = try XCTUnwrap(requests.first)

        // THEN
        XCTAssertEqual(requests.count, 1)

        XCTAssertEqual(request.url, dataURL.absoluteString)
        XCTAssertEqual(request.host, nil)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.errorDomain)
        XCTAssertEqual(request.errorCode, 0)
        XCTAssertEqual(request.requestState, LoggerNetworkRequestEntity.State.success.rawValue)

        XCTAssertNotNil(request.details)

        let message = try XCTUnwrap(request.message)
        XCTAssertEqual(message.label, "network")
    }

    func testRecordError() throws {
        // GIVEN file that doesn't exist
        let dataURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: false)

        // WHEN
        let didComplete = self.expectation(description: "TaskCompleted")
        let dataTask = URLSession.shared.dataTask(with: dataURL) { _, _, _ in
            didComplete.fulfill()
        }
        dataTask.resume()
        wait(for: [didComplete], timeout: 5)

        // RECORD
        let requests = try store.allNetworkRequests()
        let request = try XCTUnwrap(requests.first)

        // THEN
        XCTAssertEqual(requests.count, 1)

        XCTAssertEqual(request.url, dataURL.absoluteString)
        XCTAssertEqual(request.host, nil)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.errorDomain, "NSURLErrorDomain")
        XCTAssertEqual(request.errorCode, -1100)
        XCTAssertEqual(request.requestState, LoggerNetworkRequestEntity.State.failure.rawValue)

        XCTAssertNotNil(request.details)

        let message = try XCTUnwrap(request.message)
        XCTAssertEqual(message.label, "network")
    }
}
