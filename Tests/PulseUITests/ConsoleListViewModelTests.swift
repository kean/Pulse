// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import XCTest
import Combine
import CoreData
@testable import Pulse
@testable import PulseUI

final class ConsoleListViewModelTests: ConsoleTestCase {
    let filters = ConsoleFiltersViewModel(options: .init())
    var environment: ConsoleEnvironment!
    var sut: ConsoleListViewModel!

    override func setUp() {
        super.setUp()

        setUp(store: store)
    }

    func setUp(store: LoggerStore) {
        self.store = store
        self.environment = ConsoleEnvironment(store: store)
        self.environment.mode = .all
        self.sut = ConsoleListViewModel(environment: environment, filters: filters)
        self.sut.isViewVisible = true
    }

    func testThatAllLogsAreLoadedByDefault() {
        // GIVEN
        let entities = sut.entities

        // THEN
        XCTAssertEqual(entities.count, 13)
        XCTAssertTrue(entities is [LoggerMessageEntity])
    }

    func testThatEntitiesAreOrderedByCreationDate() {
        // GIVEN
        let entities = sut.entities

        // THEN
        XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
    }

    func testSwitchingToNetworkMode() {
        // WHEN
        environment.mode = .network

        // THEN
        XCTAssertEqual(environment.mode, .network)
        XCTAssertEqual(sut.entities.count, 8)
        XCTAssertTrue(sut.entities is [NetworkTaskEntity])
    }

    // MARK: Ordering

    func testOrderLogsByLevel() {
        // WHEN
        environment.mode = .all
        environment.listOptions.messageSortBy = .level
        environment.listOptions.order = .ascending

        // THEN
        XCTAssertEqual(
            sut.entities,
            (sut.entities as! [LoggerMessageEntity]).sorted(by: { $0.level < $1.level })
        )
    }

    func testOrderLogsByLevelDescending() {
        // WHEN
        environment.mode = .all
        environment.listOptions.messageSortBy = .level
        environment.listOptions.order = .descending

        // THEN
        XCTAssertEqual(
            sut.entities,
            (sut.entities as! [LoggerMessageEntity]).sorted(by: { $0.level > $1.level })
        )
    }

    // MARK: Pins

    func testPinRegularMessage() throws {
        let expectation = self.expectation(description: "pins-updated")
        expectation.expectedFulfillmentCount = 2
        sut.$pins.dropFirst().sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // GIVEN
        let message = try XCTUnwrap(store.allMessages().first(where: { $0.task == nil }))
        store.pins.togglePin(for: message)

        // THEN
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(sut.pins.count, 1)
    }

    func testThatPinsAreUpdatedWhenModeChanges() throws {
        let expectation = self.expectation(description: "pins-updated")
        expectation.expectedFulfillmentCount = 5
        sut.$pins.dropFirst().sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // GIVEN
        let message = try XCTUnwrap(store.allMessages().first(where: { $0.task == nil }))
        store.pins.togglePin(for: message)
        let task = try XCTUnwrap(store.allMessages().first(where: { $0.task != nil }))
        store.pins.togglePin(for: task)

        // WHEN
        environment.mode = .network

        // THEN only tasks is displayed
        wait(for: [expectation], timeout: 2)
        XCTAssertEqual(sut.pins.count, 1)
        XCTAssertEqual(sut.pins.first?.objectID, task.objectID)
    }
}

private func isOrderedBefore(_ lhs: NSManagedObject, _ rhs: NSManagedObject) -> Bool {
    let lhs = (lhs as? LoggerMessageEntity)?.createdAt ?? (lhs as? NetworkTaskEntity)!.createdAt
    let rhs = (rhs as? LoggerMessageEntity)?.createdAt ?? (rhs as? NetworkTaskEntity)!.createdAt
#if os(macOS)
    return lhs < rhs
#else
    return lhs > rhs
#endif
}
