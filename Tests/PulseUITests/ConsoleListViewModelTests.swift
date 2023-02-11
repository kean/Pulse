// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

@available(iOS 16, *)
final class ConsoleListViewModelTests: ConsoleTestCase {
    var criteriaViewModel: ConsoleSearchCriteriaViewModel!
    var sut: ConsoleListViewModel!

    override func setUp() {
        super.setUp()

        setUp(store: store)
    }

    func setUp(store: LoggerStore, source: ConsoleSource = .store) {
        self.store = store
        self.criteriaViewModel = ConsoleSearchCriteriaViewModel(criteria: .init(), index: .init(store: store))
        self.sut = ConsoleListViewModel(store: store, source: source, criteria: criteriaViewModel)
        self.sut.isViewVisible = true
    }

    func testThatAllLogsAreLoadedByDefault() {
        // GIVEN
        let entities = sut.entities

        // THEN
        XCTAssertEqual(entities.count, 13)
        XCTAssertTrue(entities is [LoggerMessageEntity])
        XCTAssertEqual(sut.mode, .all)
    }

    func testThatEntitiesAreOrderedByCreationDate() {
        // GIVEN
        let entities = sut.entities

        // THEN
        XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
    }

    func testSwitchingToNetworkMode() {
        // WHEN
        sut.mode = .tasks

        // THEN
        XCTAssertEqual(sut.mode, .tasks)
        XCTAssertEqual(sut.entities.count, 8)
        XCTAssertTrue(sut.entities is [NetworkTaskEntity])
    }

    // MARK: Grouping

    func testGroupingLogsByLabel() {
        // WHEN
        sut.options.messageGroupBy = .label

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
        sut.mode = .tasks
        sut.options.taskGroupBy = .taskType

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
        sut.mode = .tasks
        sut.options.taskGroupBy = .requestState

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
        sut.options.messageSortBy = .level
        sut.options.order = .ascending

        // THEN
        XCTAssertEqual(
            sut.entities,
            (sut.entities as! [LoggerMessageEntity]).sorted(by: { $0.level < $1.level })
        )
    }

    func testOrderLogsByLevelDescending() {
        // WHEN
        sut.options.messageSortBy = .level
        sut.options.order = .descending

        // THEN
        XCTAssertEqual(
            sut.entities,
            (sut.entities as! [LoggerMessageEntity]).sorted(by: { $0.level > $1.level })
        )
    }

#warning("rework")
    func _testCustomSortDescriptor() {
        // WHEN
        sut.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.level, ascending: true)]

        // THEN
        XCTAssertEqual(
            sut.entities,
            (sut.entities as! [LoggerMessageEntity]).sorted(by: { $0.level < $1.level })
        )
    }

    // MARK: Pins

    func testPinRegularMessage() throws {
        let expectation = self.expectation(description: "pins-updated")
        sut.$pins.dropFirst().sink {
            print($0)
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
        expectation.expectedFulfillmentCount = 3
        sut.$pins.dropFirst().sink { _ in
            expectation.fulfill()
        }.store(in: &cancellables)

        // GIVEN
        let message = try XCTUnwrap(store.allMessages().first(where: { $0.task == nil }))
        store.pins.togglePin(for: message)
        let task = try XCTUnwrap(store.allMessages().first(where: { $0.task != nil }))
        store.pins.togglePin(for: task)

        // WHEN
        sut.mode = .tasks

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
        setUp(store: store, source: .entities(title: "Focus", entities: entities))

        // THEN
        XCTAssertEqual(sut.entities, entities)
    }

    func testGroupingFocusedEntities() {
        // GIVEN
        let entities = Array(sut.entities[...3])
        setUp(store: store, source: .entities(title: "Focus", entities: entities))

        // WHEN
        sut.options.messageGroupBy = .level

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
