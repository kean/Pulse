// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

final class ConsoleViewModelTests: ConsoleTestCase {
    var context = ConsoleContext()
    var mode: ConsoleMode = .all
    var isOnlyNetwork = false
    var options = ConsoleListOptions()

    var sut: ConsoleViewModel!

    override func setUp() {
        super.setUp()

        reset()
    }

    private func reset() {
        sut = ConsoleViewModel(store: store, context: context, mode: mode)
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

        sut.searchCriteriaViewModel.isOnlyErrors = true
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
