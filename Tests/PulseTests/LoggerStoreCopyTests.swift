// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
import Combine
@testable import Pulse

final class LoggerStoreCopyTests: LoggerStoreBaseTests {
    var copyURL: URL!

    override func setUp() {
        super.setUp()

        store = makeStore {
            $0.makeCurrentDate = { [unowned self] in self.date }
            $0.isAutoStartingSession = false
            $0.inlineLimit = ExportableStoreConstants.inlineLimit
            $0.isBlobCompressionEnabled = false
        }

        copyURL = directory.url.appending(filename: "copy.pulse")
    }

    func testPreconditions() throws {
        // GIVEN
        populateMix(store: store)

        // THEN
        let context = store.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionOne.id, ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 2)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).count, 10)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 4)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 6)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 6)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 6)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 6)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 4)
        XCTAssertEqual(blobs.compactMap(\.inlineData).count, 2)
    }

    // MARK: Copy (Package -> Archive)

    func testCopyPackageToArchive() throws {
        // GIVEN
        populateMix(store: store)

        // WHEN copy with defaull parameter
        try store.copy(to: copyURL)

        // THEN
        let copy = try LoggerStore(storeURL: copyURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 4)
        XCTAssertEqual(info.taskCount, 6)
        XCTAssertEqual(info.blobCount, 4)
        XCTAssertEqual(info.blobsSize, 12350)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionOne.id, ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 2)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 4)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 6)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 6)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 6)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 6)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 4)
        XCTAssertEqual(blobs.compactMap(\.inlineData).count, 2)
        XCTAssertTrue(blobs.allSatisfy { $0.data != nil })
    }

    func testCopy() throws {
        // GIVEN
        populate(store: store)

        let copyURL = directory.url.appending(filename: "copy.pulse")

        // WHEN
        try store.copy(to: copyURL)

        // THEN
        try? store.close()

        // THEN
        let copy = try LoggerStore(storeURL: copyURL)
        defer { try? copy.destroy() }

        XCTAssertEqual(try copy.allMessages().count, 10)
        XCTAssertEqual(try copy.allTasks().count, 3)
    }

    func testCopyCreatesInto() throws {
        // GIVEN
        let store = makeStore()
        defer { try? store.destroy() }

        populate(store: store)
        date = Date()
        let copyURL = directory.url.appending(filename: "copy.pulse")
        try store.copy(to: copyURL)

        // WHEN
        let info = try LoggerStore.Info.make(storeURL: copyURL)

        XCTAssertEqual(info.storeVersion, "3.6.0")
        XCTAssertEqual(info.messageCount, 7)
        XCTAssertEqual(info.taskCount, 3)
        XCTAssertEqual(info.blobCount, 3)
        XCTAssertEqual(info.creationDate, date)
        XCTAssertEqual(info.modifiedDate, date)
    }

    func testCopyWithPredicate() throws {
        // GIVEN
        populate(store: store)

        let copyURL = directory.url.appending(filename: "copy.pulse")

        // WHEN
        let info = try store.copy(to: copyURL, predicate: NSPredicate(format: "level == %i", LoggerStore.Level.trace.rawValue))
        try? store.close()

        // THEN
        XCTAssertEqual(info.messageCount, 2)
        XCTAssertEqual(info.taskCount, 0)

        // THEN all non-trace messages are removed, as well as network messages
        // and associated blobs
        let copy = try LoggerStore(storeURL: copyURL)
        defer { try? copy.destroy() }

        let context = copy.viewContext
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 2)
        XCTAssertEqual(try context.count(for: NetworkTaskEntity.self), 0)
        XCTAssertEqual(try context.count(for: NetworkTaskProgressEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)
    }

    func testCopyToNonExistingFolder() throws {
        // GIVEN
        populate(store: store)

        let invalidURL = directory.url
            .appending(directory: UUID().uuidString)
            .appending(filename: "copy.pulse")

        // WHEN/THEN
        XCTAssertThrowsError(try store.copy(to: invalidURL))
    }

    func testCopyButFileExists() throws {
        // GIVEN
        populate(store: store)

        let copyURL = directory.url.appending(filename: "copy.pulse")

        try store.copy(to: copyURL)

        // WHEN/THEN
        XCTAssertThrowsError(try store.copy(to: copyURL))

        print(copyURL)
    }

    // MARK: - Copy (Archive)

    func testCopyFile() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: "logs-archive-v2.pulse")
        try Resources.pulseArchive.write(to: storeURL)

        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        let copyURL = directory.url.appending(filename: "copy.pulse")

        // WHEN
        try store.copy(to: copyURL)

        // THEN
        let copy = try LoggerStore(storeURL: copyURL)
        defer { try? copy.destroy() }

        XCTAssertEqual(try copy.allMessages().count, 15)
        XCTAssertEqual(try copy.allTasks().count, 8)
    }
}
