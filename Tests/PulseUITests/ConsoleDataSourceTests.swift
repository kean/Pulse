// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import XCTest
import Combine
import CoreData
@testable import Pulse
@testable import PulseUI

final class ConsoleDataSourceTests: ConsoleTestCase, ConsoleDataSourceDelegate {
    var sut: ConsoleDataSource!

    var mode: ConsoleMode = .all
    var listOptions = ConsoleListOptions()
    var predicate = ConsoleDataSource.PredicateOptions()

    var updates: [CollectionDifference<NSManagedObjectID>?] = []
    var onRefresh: (() -> Void)?
    var onUpdate: ((CollectionDifference<NSManagedObjectID>?) -> Void)?

    override func setUp() {
        super.setUp()

        reset()
    }

    func reset() {
        self.sut = ConsoleDataSource(store: store, mode: mode, options: listOptions)
        self.sut.delegate = self
        self.sut.refresh()
    }

    func testThatAllLogsAreLoadedByDefault() {
        // GIVEN
        let entities = sut.entities

        // THEN all logs loaded, including traces because there is no predicate by default
        XCTAssertEqual(entities.count, 15)
        XCTAssertTrue(entities is [LoggerMessageEntity])
    }

    func testThatEntitiesAreOrderedByCreationDate() {
        // GIVEN
        let entities = sut.entities

        // THEN
        XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
    }

    // MARK: Modes

    func testSwitchingToNetworkMode() {
        // WHEN
        mode = .network
        reset()

        // THEN
        XCTAssertEqual(sut.entities.count, 8)
        XCTAssertTrue(sut.entities is [NetworkTaskEntity])
    }

    // MARK: Grouping

    func testGroupingLogsByLabel() {
        // WHEN
        listOptions.messageGroupBy = .label
        reset()

        // THEN entities are still loaded
        XCTAssertEqual(sut.entities.count, 15)

        // THEN sections are created
        let sections = sut.sections ?? []
        XCTAssertEqual(sections.count, 6)

        // THEN groups are sorted by the label
        XCTAssertEqual(sections.map(\.name), ["analytics", "application", "auth", "default", "network", "session"])

        // THEN entities within these groups are sorted by creation date
        for section in sections {
            let entities = section.objects as! [NSManagedObject]
            XCTAssertEqual(entities, entities.sorted(by: isOrderedBefore))
        }
    }

    func testGroupTasks() {
        XCTAssertEqual(groupTasksBy(.url).map(sut.name), ["https://github.com/CreateAPI/Get", "https://github.com/kean/Nuke/archive/tags/11.0.0.zip", "https://github.com/login?scopes=profile,repos", "https://github.com/octocat.png", "https://github.com/profile/valdo", "https://github.com/repos", "https://github.com/repos/kean/Nuke", "https://objects-origin.githubusercontent.com/github-production-release-asset-2e65be"])
        XCTAssertEqual(groupTasksBy(.host).map(sut.name), ["github.com", "objects-origin.githubusercontent.com"])
        XCTAssertEqual(groupTasksBy(.method).map(sut.name), ["GET", "PATCH", "POST"])
        XCTAssertEqual(groupTasksBy(.statusCode).map(sut.name), ["200 OK", "204 No Content", "404 Not Found"])
        XCTAssertEqual(groupTasksBy(.errorCode).map(sut.name), ["4864", "–"])
        XCTAssertEqual(groupTasksBy(.requestState).map(sut.name), ["Success", "Failure"])
        XCTAssertEqual(groupTasksBy(.responseContentType).map(sut.name), ["–", "application/html", "application/json", "application/zip", "image/png", "text/html"])
        XCTAssertFalse(groupTasksBy(.session).isEmpty)
    }

    func groupTasksBy(_ grouping: ConsoleListOptions.TaskGroupBy) -> [NSFetchedResultsSectionInfo] {
        mode = .network
        listOptions.taskGroupBy = grouping
        reset()
        return sut.sections ?? []
    }

    // MARK: Sorting

    func testSetCustomSortDescriptors() throws {
        // WHEN
        sut.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.level, ascending: true)]
        sut.refresh()

        // THEN
        let messages = try XCTUnwrap(sut.entities as? [LoggerMessageEntity])
        XCTAssertEqual(messages, messages.sorted(by: { $0.level < $1.level }))
    }

    // MARK: Delegate

    func testWhenMessageIsInsertedDelegateIsCalled() throws {
        let expectation = self.expectation(description: "onUpdate")
        onUpdate = { _ in expectation.fulfill() }

        // WHEN
        store.storeMessage(label: "test", level: .debug, message: "test")

        // THEN delegate is called
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(updates.count, 1)
        let diff = try XCTUnwrap(XCTUnwrap(updates.first))

        // THEN item is inserted at the bottom
        XCTAssertEqual(diff.count, 1)
        let change = try XCTUnwrap(diff.first)
        switch change {
        case let .insert(offset, _, _):
#if os(macOS)
            XCTAssertEqual(offset, 15)
#else
            XCTAssertEqual(offset, 0)
#endif
        case .remove:
            XCTFail()
        }

        // THEN entities are updated
        XCTAssertTrue(sut.entities.contains(where: {
            ($0 as! LoggerMessageEntity).text == "test" })
        )
    }

    func testWhenMessageIsInsertedInGroupedDataSourceDelegateIsCalled() throws {
        // GIVEN
        listOptions.messageGroupBy = .level
        reset()

        let expectation = self.expectation(description: "onUpdate")
        onUpdate = { _ in expectation.fulfill() }

        // WHEN
        store.storeMessage(label: "test", level: .debug, message: "test")

        // THEN delegate is called
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(updates.count, 1)
        let diff = try XCTUnwrap(updates.first)

        // THEN diff is empty because it's not supported for sectioned request
        XCTAssertNil(diff)

        // THEN entities are updated
        XCTAssertTrue(sut.entities.contains(where: {
            ($0 as! LoggerMessageEntity).text == "test" })
        )

        // THEN sections are updated
        XCTAssertTrue((sut.sections ?? []).contains(where: {
            ($0.objects as! [LoggerMessageEntity]).contains(where: {
                $0.text == "test"
            })
        }))
    }

    // MARK: ConsoleFiltersViewModel

    func testDataSourceIsRefreshedWithInitialSearchCriteria() {
        var didRefresh = false
        onRefresh = { didRefresh = true }

        // WHEN
        sut.predicate.isOnlyErrors = true

        // THEN delegate is called
        XCTAssertTrue(didRefresh)

        // THEN only errors are displayed
        XCTAssertEqual(sut.entities.count, 3)
        XCTAssertTrue(sut.entities.allSatisfy({
            ($0 as! LoggerMessageEntity).logLevel >= .error
        }))
    }

    func testWhenCriteriaChangesEntitiesAreRefreshed() {
        // GIVEN
        sut.refresh()
        XCTAssertEqual(sut.entities.count, 15)

        // WHEN
        var didRefresh = false
        onRefresh = { didRefresh = true }

        sut.predicate.isOnlyErrors = true

        // THEN delegate is called
        XCTAssertTrue(didRefresh)

        // THEN only errors are displayed
        XCTAssertEqual(sut.entities.count, 3)
        XCTAssertTrue(sut.entities.allSatisfy({
            ($0 as! LoggerMessageEntity).logLevel >= .error
        }))
    }

    // MARK: ConsoleDataSourceDelegate

    func dataSourceDidRefresh(_ dataSource: ConsoleDataSource) {
        onRefresh?()
    }

    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?) {
        updates.append(diff)
        onUpdate?(diff)
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
