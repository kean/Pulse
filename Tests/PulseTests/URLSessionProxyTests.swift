// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
import Foundation
import CoreData
@testable import PulseCore

final class URLSessionProxyTests: XCTestCase {
    let directory = TemporaryDirectory()
    var store: LoggerStore!
    var logger: NetworkLogger!

    override func setUp() {
        let storeURL = directory.url.appendingFilename("logs.pulse")
        store = try! LoggerStore(storeURL: storeURL, options: [.create])
        logger = NetworkLogger(store: store)

        Experimental.URLSessionProxy.shared.logger = logger
        Experimental.URLSessionProxy.shared.isEnabled = true
    }

    override func tearDown() {
        store.destroyStores()

        directory.remove()

        Experimental.URLSessionProxy.shared.isEnabled = false
    }

    func testRecordSuccess() throws {
        // WHEN
        let dataURL = directory.url.appendingPathComponent("logs-2021-03-18_21-22.pulse")
        try Resources.pulseArchive.write(to: dataURL)
        let didComplete = self.expectation(description: "TaskCompleted")
        let dataTask = URLSession.shared.dataTask(with: dataURL) { _, _, _ in
            didComplete.fulfill()
        }
        dataTask.resume()
        wait(for: [didComplete], timeout: 5)

        // RECORD
        flush(store: store)
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

        XCTAssertNil(request.requestBodyKey)
        XCTAssertNotNil(request.responseBodyKey)

        XCTAssertNotNil(request.details)

        let message = try XCTUnwrap(request.message)
        XCTAssertEqual(message.label, "network")
    }

    func testRecordError() throws {
        // GIVEN file that doesn't exist
        let dataURL = FileManager.default.temporaryDirectory.appendingFilename(UUID().uuidString)

        // WHEN
        let didComplete = self.expectation(description: "TaskCompleted")
        let dataTask = URLSession.shared.dataTask(with: dataURL) { _, _, _ in
            didComplete.fulfill()
        }
        dataTask.resume()
        wait(for: [didComplete], timeout: 5)

        // RECORD
        flush(store: store)
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

        XCTAssertNil(request.requestBodyKey)
        XCTAssertNil(request.responseBodyKey)

        XCTAssertNotNil(request.details)

        let message = try XCTUnwrap(request.message)
        XCTAssertEqual(message.label, "network")
    }
}
