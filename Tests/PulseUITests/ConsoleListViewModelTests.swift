// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

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

    func setUp(store: LoggerStore, focusedEntities: [NSManagedObject]? = nil) {
        self.store = store
        self.environment = ConsoleEnvironment(store: store)
        self.environment.mode = .all
        if let entities = focusedEntities {
            filters.options.focus = NSPredicate(format: "self IN %@", entities)
        }
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

    // MARK: Grouping

    func testGroupingLogsByLabel() {
        // WHEN
        environment.listOptions.messageGroupBy = .label

        // THEN entities are still loaded
        XCTAssertEqual(sut.entities.count, 13)

        // THEN sections are created
        let sections = sut.sections ?? []
        XCTAssertEqual(sections.count, 5)

        // THEN groups are sorted by the label
        XCTAssertEqual(sections.map(\.name), ["analytics", "application", "auth", "default", "network"])

        // THEN entities within these groups are sorted by creation date
        for section in sections {
            let entities = section.objects as! [NSManagedObject]
            XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
        }
    }

    func testGroupingTasksByTaskType() {
        // WHEN
        environment.mode = .network
        environment.listOptions.taskGroupBy = .taskType

        // THEN entities are still loaded
        XCTAssertEqual(sut.entities.count, 8)

        // THEN sections are created
        let sections = sut.sections ?? []
        XCTAssertEqual(sections.count, 3)

        // THEN groups are sorted by the label
        XCTAssertEqual(sections.map(sut.name), ["URLSessionDataTask", "URLSessionDownloadTask", "URLSessionUploadTask"])

        // THEN entities within these groups are sorted by creation date
        for section in sections {
            let entities = section.objects as! [NSManagedObject]
            XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
        }
    }

    func testGroupingTasksByStatus() {
        // WHEN
        environment.mode = .network
        environment.listOptions.taskGroupBy = .requestState

        // THEN entities are still loaded
        XCTAssertEqual(sut.entities.count, 8)

        // THEN sections are created
        let sections = sut.sections ?? []
        XCTAssertEqual(sections.count, 2)

        // THEN groups are sorted by the label
        XCTAssertEqual(sections.map(sut.name), ["Success", "Failure"])

        // THEN entities within these groups are sorted by creation date
        for section in sections {
            let entities = section.objects as! [NSManagedObject]
            XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
        }
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

    // MARK: Focus

    func testFocusOnEntities() throws {
        // GIVEN
        let entities = Array(sut.entities[...3])

        // WHEN
        setUp(store: store, focusedEntities: entities)

        // THEN
        XCTAssertEqual(sut.entities, entities)
    }
    
#if os(macOS)
    func testGroupingFocusedEntities() {
        // GIVEN
        let entities = Array(sut.entities[...3])
        setUp(store: store, focusedEntities: entities)
        
        // WHEN
        environment.listOptions.messageGroupBy = .level
        
        // THEN entities are still loaded
        XCTAssertEqual(sut.entities.count, 4)
        
        // THEN sections are created
        let sections = sut.sections ?? []
        XCTAssertEqual(sections.count, 2)
        
        // THEN groups are sorted by the label
        XCTAssertEqual(sections.map(sut.name), ["Info", "Debug"])
        
        // THEN entities within these groups are sorted by creation date
        for section in sections {
            let entities = section.objects as! [NSManagedObject]
            XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
        }
    }
#endif
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
