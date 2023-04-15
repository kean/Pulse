// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
import Combine
@testable import Pulse

final class LoggerStoreExportTests: LoggerStoreBaseTests {
    var targetURL: URL!
    var archiveURL: URL!

    override func setUp() {
        super.setUp()

        store = makeStore {
            $0.makeCurrentDate = { [unowned self] in self.date }
            $0.isAutoStartingSession = false
            $0.inlineLimit = ExportableStoreConstants.inlineLimit
            $0.isBlobCompressionEnabled = false
        }

        targetURL = directory.url.appending(filename: "copy.pulse")
        archiveURL = directory.url.appending(filename: "archive.pulse")
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

    // MARK: Export (Package -> Archive)

    func testExportPackageToArchive() async throws {
        // GIVEN
        populateMix(store: store)

        // WHEN export with default parameters
        try await store.export(to: targetURL)

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
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

    func testExportPackageToArchiveWithPredicate() async throws {
        // GIVEN
        populateMix(store: store)

        let blobKeys = try store.viewContext.fetch(LoggerBlobHandleEntity.self).map(\.key)

        // WHEN export with predicate to keep only errors
        let predicate = NSPredicate(format: "level >= %i", LoggerStore.Level.error.rawValue)
        try await store.export(to: targetURL, options: .init(predicate: predicate))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 0)
        XCTAssertEqual(info.blobCount, 0)
        XCTAssertEqual(info.blobsSize, 0)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionOne.id, ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 2)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 0)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 0)
        XCTAssertEqual(blobKeys.compactMap({ copy.getDecompressedData(for: nil, key: $0, isCompressed: false) }).count, 0)
    }

    func testExportPackageToArchiveWithSessions() async throws {
        // GIVEN
        populateMix(store: store)

        // WHEN export with session scope
        try await store.export(to: targetURL, options: .init(sessions: [ExportableStoreConstants.sessionTwo.id]))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 3)
        XCTAssertEqual(info.blobCount, 3)
        XCTAssertEqual(info.blobsSize, 5350)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).count, 4)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 3)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 3)
        XCTAssertEqual(blobs.compactMap(\.inlineData).count, 2)
        XCTAssertTrue(blobs.allSatisfy { $0.data != nil })
    }

    // MARK: Export (Package -> Package)

    func testExportPackageToPackage() async throws {
        // GIVEN
        populateMix(store: store)

        // WHEN export with default parameters
        try await store.export(to: targetURL, as: .package)

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
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

    func testExportPackageToPackageWithPredicate() async throws {
        // GIVEN
        populateMix(store: store)

        let blobKeys = try store.viewContext.fetch(LoggerBlobHandleEntity.self).map(\.key)

        // WHEN export with predicate to keep only errors
        let predicate = NSPredicate(format: "level >= %i", LoggerStore.Level.error.rawValue)
        try await store.export(to: targetURL, as: .package, options: .init(predicate: predicate))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 0)
        XCTAssertEqual(info.blobCount, 0)
        XCTAssertEqual(info.blobsSize, 0)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionOne.id, ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 2)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 0)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 0)
        XCTAssertEqual(blobKeys.compactMap({ copy.getDecompressedData(for: nil, key: $0, isCompressed: false) }).count, 0)
    }

    func testExportPackageToPackageWithSessions() async throws {
        // GIVEN
        populateMix(store: store)

        // WHEN export with session scope
        try await store.export(to: targetURL, as: .package, options: .init(sessions: [ExportableStoreConstants.sessionTwo.id]))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 3)
        XCTAssertEqual(info.blobCount, 3)
        XCTAssertEqual(info.blobsSize, 5350)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).count, 4)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 3)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 3)
        XCTAssertEqual(blobs.compactMap(\.inlineData).count, 2)
        XCTAssertTrue(blobs.allSatisfy { $0.data != nil })
    }

    // MARK: Export (Archive -> Archive)

    func testExportArchiveToArchive() async throws {
        // GIVEN
        populateMix(store: store)
        try await store.export(to: archiveURL)
        let archive = try LoggerStore(storeURL: archiveURL, options: .readonly)

        // WHEN export with default parameters
        try await archive.export(to: targetURL)

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
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

    func testExportArchiveToArchiveWithPredicate() async throws {
        // GIVEN
        populateMix(store: store)
        try await store.export(to: archiveURL)
        let archive = try LoggerStore(storeURL: archiveURL, options: .readonly)

        let blobKeys = try archive.viewContext.fetch(LoggerBlobHandleEntity.self).map(\.key)

        // WHEN copy with predicate to keep only errors
        let predicate = NSPredicate(format: "level >= %i", LoggerStore.Level.error.rawValue)
        try await archive.export(to: targetURL, options: .init(predicate: predicate))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 0)
        XCTAssertEqual(info.blobCount, 0)
        XCTAssertEqual(info.blobsSize, 0)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionOne.id, ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 2)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 0)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 0)
        XCTAssertEqual(blobKeys.compactMap({ copy.getDecompressedData(for: nil, key: $0, isCompressed: false) }).count, 0)
    }

    func testExportArchiveToArchiveWithSessions() async throws {
        // GIVEN
        populateMix(store: store)
        try await store.export(to: archiveURL)
        let archive = try LoggerStore(storeURL: archiveURL, options: .readonly)

        // WHEN copy with session scope
        try await archive.export(to: targetURL, options: .init(sessions: [ExportableStoreConstants.sessionTwo.id]))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 3)
        XCTAssertEqual(info.blobCount, 3)
        XCTAssertEqual(info.blobsSize, 5350)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).count, 4)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 3)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 3)
        XCTAssertEqual(blobs.compactMap(\.inlineData).count, 2)
        XCTAssertTrue(blobs.allSatisfy { $0.data != nil })
    }

    // MARK: Export (Archive -> Package)

    func testExportArchiveToPackage() async throws {
        // GIVEN
        populateMix(store: store)
        try await store.export(to: archiveURL)
        let archive = try LoggerStore(storeURL: archiveURL, options: .readonly)

        // WHEN export with default parameters
        try await archive.export(to: targetURL, as: .package)

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
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

    func testExportArchiveToPackageWithPredicate() async throws {
        // GIVEN
        populateMix(store: store)
        try await store.export(to: archiveURL)
        let archive = try LoggerStore(storeURL: archiveURL, options: .readonly)

        let blobKeys = try archive.viewContext.fetch(LoggerBlobHandleEntity.self).map(\.key)

        // WHEN export with predicate to keep only errors
        let predicate = NSPredicate(format: "level >= %i", LoggerStore.Level.error.rawValue)
        try await archive.export(to: targetURL, as: .package, options: .init(predicate: predicate))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 0)
        XCTAssertEqual(info.blobCount, 0)
        XCTAssertEqual(info.blobsSize, 0)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionOne.id, ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 2)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 0)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 0)
        XCTAssertEqual(blobKeys.compactMap({ copy.getDecompressedData(for: nil, key: $0, isCompressed: false) }).count, 0)
    }

    func testExportArchiveToPackageWithSessions() async throws {
        // GIVEN
        populateMix(store: store)
        try await store.export(to: archiveURL)
        let archive = try LoggerStore(storeURL: archiveURL, options: .readonly)

        // WHEN export with session scope
        try await archive.export(to: targetURL, as: .package, options: .init(sessions: [ExportableStoreConstants.sessionTwo.id]))

        // THEN
        let copy = try LoggerStore(storeURL: targetURL)
        defer { try? copy.destroy() }

        // THEN info is exported
        let info = try copy.info()
        XCTAssertNotEqual(info.storeId, try store.info().storeId)
        XCTAssertEqual(info.messageCount, 1)
        XCTAssertEqual(info.taskCount, 3)
        XCTAssertEqual(info.blobCount, 3)
        XCTAssertEqual(info.blobsSize, 5350)

        // THEN entities are exported
        let context = copy.viewContext

        XCTAssertEqual(
            Set(try context.fetch(LoggerSessionEntity.self).map(\.id)),
            Set([ExportableStoreConstants.sessionTwo.id])
        )

        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).filter { $0.task == nil }.count, 1)
        XCTAssertEqual(try context.fetch(LoggerMessageEntity.self).count, 4)
        XCTAssertEqual(try context.fetch(NetworkTaskEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTaskProgressEntity.self).count, 0)
        XCTAssertEqual(try context.fetch(NetworkRequestEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkResponseEntity.self).count, 3)
        XCTAssertEqual(try context.fetch(NetworkTransactionMetricsEntity.self).count, 3)

        let blobs = try context.fetch(LoggerBlobHandleEntity.self)
        XCTAssertEqual(blobs.count, 3)
        XCTAssertEqual(blobs.compactMap(\.inlineData).count, 2)
        XCTAssertTrue(blobs.allSatisfy { $0.data != nil })
    }

    // MARK: Export (Error Handling)

    func testExportToNonExistingFolder() async throws {
        // GIVEN
        populate(store: store)

        let invalidURL = directory.url
            .appending(directory: UUID().uuidString)
            .appending(filename: "copy.pulse")

        // WHEN/THEN
        do {
            try await store.export(to: invalidURL)
            XCTFail("Expected an error")
        } catch {
            if let error = error as? LoggerStore.Error, case .fileDoesntExist = error {
                // OK
            } else {
                XCTFail("Unexpected error")
            }
        }
    }

    func testExportButFileExists() async throws {
        // GIVEN
        populate(store: store)

        let copyURL = directory.url.appending(filename: "copy.pulse")

        try await store.export(to: copyURL)

        // WHEN/THEN
        do {
            try await store.export(to: copyURL)
            XCTFail("Expected an error")
        } catch {
            if let error = error as? LoggerStore.Error, case .fileAlreadyExists = error {
                // OK
            } else {
                XCTFail("Unexpected error")
            }
        }
    }
}
