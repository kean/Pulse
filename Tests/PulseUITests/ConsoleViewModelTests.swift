// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

final class ConsoleEnvironmentTests: ConsoleTestCase {
    var mode: ConsoleMode = .all
    var isOnlyNetwork = false
    var options = ConsoleListOptions()

    var sut: ConsoleEnvironment!

    override func setUp() {
        super.setUp()

        reset()
    }

    private func reset() {
        sut = ConsoleEnvironment(store: store, mode: mode)
    }

    // MARK: Counters

    func testCountersArePopulatedWithInitialValues() {
        XCTAssertEqual(sut.logCountObserver.count, 5)
        XCTAssertEqual(sut.taskCountObserver.count, 8)
    }

    func testCountersAreUpdatedWhenPredicatesAre() {
        let expectation = self.expectation(description: "countersUpdated")
        expectation.expectedFulfillmentCount = 2

        sut.logCountObserver.$count.dropFirst().sink {
            XCTAssertEqual($0, 1)
            expectation.fulfill()
        }.store(in: &cancellables)

        sut.taskCountObserver.$count.dropFirst().sink {
            XCTAssertEqual($0, 2)
            expectation.fulfill()
        }.store(in: &cancellables)

        sut.filters.options.isOnlyErrors = true
        wait(for: [expectation], timeout: 2)
    }

    func testCountersAreUpdatedWhenMessageIsInserted() {
        let expectation = self.expectation(description: "countersUpdated")

        sut.logCountObserver.$count.dropFirst().sink {
            XCTAssertEqual($0, 6)
            expectation.fulfill()
        }.store(in: &cancellables)

        store.storeMessage(label: "test", level: .debug, message: "test")

        wait(for: [expectation], timeout: 2)
    }

    func testCountersAreUpdatedWhenTaskIsInserted() {
        let expectation = self.expectation(description: "countersUpdated")

        sut.taskCountObserver.$count.dropFirst().sink {
            XCTAssertEqual($0, 9)
            expectation.fulfill()
        }.store(in: &cancellables)

        store.storeRequest(URLRequest(url: URL(string: "example.com")!), response: nil, error: nil, data: nil)

        wait(for: [expectation], timeout: 2)
    }
}
