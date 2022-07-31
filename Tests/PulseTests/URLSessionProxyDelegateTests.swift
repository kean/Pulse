// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import Logging
import XCTest
import Foundation
import CoreData
@testable import PulseCore

final class URLSessionProxyDelegateTests: XCTestCase {
    let directory = TemporaryDirectory()
    var store: LoggerStore!
    var logger: NetworkLogger!

    override func setUp() {
        super.setUp()

        let storeURL = directory.url.appendingFilename("logs.pulse")
        store = try! LoggerStore(storeURL: storeURL, options: [.create])
        logger = NetworkLogger(store: store)
    }

    override func tearDown() {
        super.tearDown()

        store.destroyStores()
        directory.remove()
    }

    func testProxyDelegate() throws {
        // GIVEN
        var myDelegate: MockSessionDelegate? = MockSessionDelegate()
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: myDelegate)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        // WHEN
        let dataURL = directory.url.appendingPathComponent("logs-2021-03-18_21-22.pulse")
        try Resources.pulseArchive.write(to: dataURL)
        let dataTask = session.dataTask(with: dataURL)

        let didComplete = self.expectation(description: "TaskCompleted")
        myDelegate?.completion = { task, error in
            if task === dataTask {
                XCTAssertNil(error)
                didComplete.fulfill()
            }
        }

        autoreleasepool {
            myDelegate = nil // Make sure that proxy delegate retain the real one (like URLSession does)
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

    func testForwardingOfUnimplementedMethod() throws {
        // GIVEN
        // - proxy delegate doesn't implement a method
        // - an actual delegate does
        let myDelegate = MockSessionCustomMethodImplemented()
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: myDelegate)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        // WHEN
        // THEN method is forwarded to the actual delegate
        let didBecomeInvalid = self.expectation(description: "didBecomeInvalid")
        myDelegate.didBecomeInvalid = { _ in
            didBecomeInvalid.fulfill()
        }
        session.invalidateAndCancel()
        wait(for: [didBecomeInvalid], timeout: 5)
    }

    func testForwardingOfUnimplementedMethodWhenDelegateIsNotRetained() throws {
        // GIVEN
        // - proxy delegate doesn't implement a method
        // - an actual delegate does
        var myDelegate: MockSessionCustomMethodImplemented? = MockSessionCustomMethodImplemented()
        let delegate = URLSessionProxyDelegate(logger: logger, delegate: myDelegate)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)

        // WHEN
        // THEN method is forwarded to the actual delegate
        let didBecomeInvalid = self.expectation(description: "didBecomeInvalid")
        myDelegate?.didBecomeInvalid = { _ in
            didBecomeInvalid.fulfill()
        }
        autoreleasepool {
            myDelegate = nil
        }

        session.invalidateAndCancel()
        wait(for: [didBecomeInvalid], timeout: 5)
    }

    func xtestAutomaticRegistration() throws {
        URLSessionProxyDelegate.enableAutomaticRegistration(logger: .init(store: store))

        let myDelegate = MockSessionDelegate()
        let session = URLSession(configuration: .default, delegate: myDelegate, delegateQueue: nil)

        // WHEN
        let dataURL = directory.url.appendingPathComponent("logs-2021-03-18_21-22.pulse")
        try Resources.pulseArchive.write(to: dataURL)
        let dataTask = session.dataTask(with: dataURL)

        let didComplete = self.expectation(description: "TaskCompleted")
        myDelegate.completion = { task, error in
            if task === dataTask {
                XCTAssertNil(error)
                didComplete.fulfill()
            }
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
}

private final class MockSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {

    var completion: ((URLSessionTask, Error?) -> Void)?

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        completion?(task, error)
    }
}

private final class MockSessionCustomMethodImplemented: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    var didBecomeInvalid: ((Error?) -> Void)?

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        didBecomeInvalid?(error)
    }
}
