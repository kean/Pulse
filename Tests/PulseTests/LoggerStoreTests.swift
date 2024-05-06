// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
import Combine
@testable import Pulse

final class LoggerStoreTests: LoggerStoreBaseTests {
    // MARK: - Init

    override func setUp() {
        super.setUp()

        store = try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous])
    }

    func testInitStoreMissing() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: UUID().uuidString)

        // WHEN/THEN
        XCTAssertThrowsError(try LoggerStore(storeURL: storeURL))
    }

    // Run this N times.
    func testConcurrentStoreInit() throws {
        let expectation = self.expectation(description: "init")
        expectation.expectedFulfillmentCount = 2
        DispatchQueue.main.async {
            let _ = LoggerStore.shared
            expectation.fulfill()
        }
        DispatchQueue.global().async {
            let _ = LoggerStore.shared
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testInitCreateStoreURL() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: UUID().uuidString)
        let options: LoggerStore.Options = [.create, .synchronous]

        // WHEN
        let firstStore = try LoggerStore(storeURL: storeURL, options: options)
        populate(store: firstStore)

        let secondStore = try LoggerStore(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try secondStore.allMessages().count, 10)

        // CLEANUP
        try? firstStore.destroy()
        try? secondStore.destroy()
    }

    func testInitCreateInMemoryStore() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: UUID().uuidString)
        let options: LoggerStore.Options = [.create, .synchronous, .inMemory]

        // WHEN
        let store = try LoggerStore(storeURL: storeURL, options: options)
        populate(store: store)

        // THEN data is NOT persisted
        let databaseURL = storeURL.appending(filename: "logs.sqlite")
        XCTAssertFalse(FileManager.default.fileExists(atPath: databaseURL.path))

        // CLEANUP
        try? store.destroy()
    }

    func testInitCreateStoreIntermediateDirectoryMissing() throws {
        // GIVEN
        let storeURL = directory.url
            .appending(directory: UUID().uuidString)
            .appending(filename: UUID().uuidString)
        let options: LoggerStore.Options = [.create]

        // WHEN/THEN
        XCTAssertThrowsError(try LoggerStore(storeURL: storeURL, options: options))
    }

    func testInitStoreWithURL() throws {
        // GIVEN
        populate(store: store)
        XCTAssertEqual(try store.allMessages().count, 10)

        let originalStore = store
        try? store.close()

        // WHEN loading the store with the same url
        store = try LoggerStore(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try store.allMessages().count, 10)

        // CLEANUP
        try? originalStore?.destroy()
    }

    func testInitWithArchiveURL() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: "logs-archive-latest.pulse")
        try Resources.pulseArchive.write(to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { try? store.destroy() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 15)
        XCTAssertEqual(try store.viewContext.count(for: NetworkTaskEntity.self), 8)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 7)

        // THEN data stored in external storage also persist
        let request = try XCTUnwrap(store.viewContext.first(NetworkTaskEntity.self) {
            $0.predicate = NSPredicate(format: "url == %@", "https://github.com/repos")
        })
        XCTAssertEqual(request.responseBodySize, 165061)
        let blob = benchmark(title: "Access Blob") {
            return request.responseBody?.data
        }
        XCTAssertEqual(blob?.count, 165061)
    }

    func testInitWithArchiveURLNoExtension() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: "logs-archive-latest")
        try Resources.pulseArchive.write(to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { try? store.destroy() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 15)
        XCTAssertEqual(try store.viewContext.count(for: NetworkTaskEntity.self), 8)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 7)

        // THEN data stored in external storage also persist
        let request = try XCTUnwrap(store.viewContext.first(NetworkTaskEntity.self) {
            $0.predicate = NSPredicate(format: "url == %@", "https://github.com/repos")
        })
        XCTAssertEqual(request.responseBodySize, 165061)
        XCTAssertEqual(request.responseBody?.data?.count, 165061)
    }

    func testInitWithPackageURL() throws {
        // GIVEN
        let storeURL = try makePulsePackage()

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { try? store.destroy() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 10)
        XCTAssertEqual(try store.viewContext.count(for: NetworkTaskEntity.self), 3)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 3)
    }

    func testInitWithPackageURLNoExtension() throws {
        // GIVEN
        let storeURL = try makePulsePackage()

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { try? store.destroy() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 10)
        XCTAssertEqual(try store.viewContext.count(for: NetworkTaskEntity.self), 3)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 3)
    }

    // MARK: - Backward Compatibility

    func testOpenOldStore_v3_1() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: "logs-archive-3-1.pulse")
        try Resources.pulseArchive_v3_1.write(to: storeURL)

        // WHEN
        let store = try LoggerStore(storeURL: storeURL)

        // THEN store version is retained
        XCTAssertEqual(store.version, "3.1.0")

        // THEN message are loaded
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 15)
        let message = try XCTUnwrap(messages.first)
        XCTAssertEqual(message.level, 3)
        XCTAssertEqual(message.text, "UIApplication.didFinishLaunching")
        XCTAssertEqual(message.label, "application")
        XCTAssertEqual(message.rawMetadata, "custom-metadata-key: value")

        // THEN tasks are loaded
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 8)
        let task = try XCTUnwrap(tasks.first)
        XCTAssertEqual(task.url, "https://github.com/profile/valdo")

        // THEN blobs are readable
        for blob in try store.viewContext.fetch(LoggerBlobHandleEntity.self) {
            let blob = try XCTUnwrap(blob.data)
            XCTAssertFalse(blob.isEmpty)
        }
    }

    func testOpenOldStore_v3_3() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: "logs-archive-3-3.pulse")
        try Resources.pulseArchive_v3_3.write(to: storeURL)

        // WHEN
        let store = try LoggerStore(storeURL: storeURL)

        // THEN store version is retained
        XCTAssertEqual(store.version, "3.1.0") // This change was made without incrementing the version

        // THEN message are loaded
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 15)
        let message = try XCTUnwrap(messages.first)
        XCTAssertEqual(message.level, 3)
        XCTAssertEqual(message.text, "UIApplication.didFinishLaunching")
        XCTAssertEqual(message.label, "application")
        XCTAssertEqual(message.rawMetadata, "custom-metadata-key: value")

        // THEN tasks are loaded
        let tasks = try store.allTasks()
        XCTAssertEqual(tasks.count, 8)
        let task = try XCTUnwrap(tasks.last)
        XCTAssertEqual(task.url, "https://github.com/repos/kean/Nuke")

        // THEN blobs are readable
        for blob in try store.viewContext.fetch(LoggerBlobHandleEntity.self) {
            let blob = try XCTUnwrap(blob.data)
            XCTAssertFalse(blob.isEmpty)
        }
    }

    // MARK: - Store Request

    func testStoreRequestWithDefaultLabel() throws {
        // WHEN
        store.storeRequest(URLRequest(url: URL(string: "https://example.com")!), response: nil, error: nil, data: nil)

        // THEN default "network" label is used
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.label, "network")
    }

    func testStoreRequestWithCustomLabel() throws {
        // WHEN
        store.storeRequest(URLRequest(url: URL(string: "https://example.com")!), response: nil, error: nil, data: nil, label: "auth")

        // THEN custom label is used
        let message = try XCTUnwrap(store.allMessages().first)
        XCTAssertEqual(message.label, "auth")
    }

    // MARK: - File (Readonly)

    // TODO: this type of store is no longer immuatble
    func _testOpenFileDatabaseImmutable() throws {
        // GIVEN
        let storeURL = directory.url.appending(filename: "logs-archive-v2.pulse")
        try Resources.pulseArchive.write(to: storeURL)

        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        XCTAssertEqual(try store.allMessages().count, 23)

        // WHEN/THEN
        store.storeMessage(label: "test", level: .info, message: "test", metadata: nil)

        // THEN nothing is written
        XCTAssertEqual(try store.allMessages().count, 23)

        let storeCopy = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        XCTAssertEqual(try storeCopy.allMessages().count, 23)
    }

    // MARK: - Expiration

    func testSizeLimit() async throws {
        let store = try! LoggerStore(
            storeURL: directory.url.appending(filename: UUID().uuidString),
            options: [.create, .synchronous],
            configuration: .init(sizeLimit: 5000)
        )
        defer { try? store.destroy() }

        // GIVEN
        let context = store.viewContext

        store.storeRequest(URLRequest(url: URL(string: "example.com/delete-this")!), response: nil, error: nil, data: "hello".data(using: .utf8))
        for index in 1...500 {
            store.storeMessage(label: "default", level: .debug, message: "\(index)", metadata: {
                index % 50 == 0 ? ["key": .stringConvertible(index)] : nil
            }())
        }

        let copyURL = directory.url
            .appending(filename: UUID().uuidString)
            .appendingPathExtension("pulse")
        try await store.export(to: copyURL)

        // SANITY
        var messages = try store.allMessages()
        XCTAssertEqual(messages.count, 501)
        XCTAssertEqual(messages.last?.text, "500")

        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 501)
        XCTAssertEqual(try context.count(for: NetworkTaskEntity.self), 1)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 1)
        context.reset()

        // WHEN
        store.syncSweep()

        // THEN
        let copyURL2 = directory.url
            .appending(filename: UUID().uuidString)
            .appendingPathExtension("pulse")
        try await store.export(to: copyURL2)

        // THEN unwanted messages were removed
        messages = try context.fetch(LoggerMessageEntity.self)
        XCTAssertEqual(messages.count, 351)
        XCTAssertEqual(messages.last?.text, "500") // Latest stored

        // THEN metadata, network requests, blobs are removed
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 351)
        XCTAssertEqual(try context.count(for: NetworkTaskEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)
    }

    func testMaxAgeSweep() throws {
        // GIVEN the store with 5 minute max age
        let store = makeStore {
            $0.maxAge = 300
            $0.isAutoStartingSession = false
        }
        defer { try? store.destroy() }

        let sessionOneID = UUID()
        let sessionTwoID = UUID()

        // GIVEN some messages stored before the cutoff date
        date = Date().addingTimeInterval(-1000)
        store.startSession(.init(id: sessionOneID, startDate: date), info: .make())
        store.storeMessage(label: "deleted", level: .debug, message: "test")
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted")!), response: nil, error: nil, data: nil)

        // GIVEN some messages stored after
        date = Date()
        store.startSession(.init(id: sessionTwoID, startDate: date), info: .make())
        store.storeMessage(label: "kept", level: .debug, message: "test")
        store.storeRequest(URLRequest(url: URL(string: "example.com/kept")!), response: nil, error: nil, data: nil)

        // ASSERT
        let context = store.backgroundContext
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 4)
        XCTAssertEqual(try context.count(for: NetworkTaskEntity.self), 2)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)
        context.reset()

        // WHEN
        store.syncSweep()

        // THEN session one is deleted
        XCTAssertEqual(try context.fetch(LoggerSessionEntity.self).map(\.id), [sessionTwoID])
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 2)
        XCTAssertEqual(try context.count(for: NetworkTaskEntity.self), 1)
        XCTAssertEqual(try context.count(for: NetworkTaskProgressEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)

        XCTAssertEqual(try store.allMessages().first?.label, "kept")
        XCTAssertEqual(try store.allTasks().first?.url, "example.com/kept")
    }

    func testMaxAgeSweepBlobIsDeletedWhenEntityIsDeleted() throws {
        // GIVEN the store with 5 minute max age
        let store = makeStore {
            $0.maxAge = 300
            $0.isAutoStartingSession = false
        }
        defer { try? store.destroy() }

        // GIVEN a request with response body stored
        date = Date().addingTimeInterval(-1000)
        let responseData = "body".data(using: .utf8)!
        store.startSession(.init(id: UUID(), startDate: date), info: .make())
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted")!), response: nil, error: nil, data: responseData)

        // ASSERT
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
        XCTAssertEqual(try store.backgroundContext.first(LoggerBlobHandleEntity.self)?.data, responseData)

        // WHEN
        date = Date()
        store.syncSweep()

        // THEN associated data is deleted
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerMessageEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: NetworkTaskEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: NetworkTaskProgressEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 0)
    }

    func testMaxAgeSweepBlobIsDeletedWhenBothEntitiesReferencingItAre() throws {
        // GIVEN the store with 5 minute max age
        let store = makeStore {
            $0.maxAge = 300
            $0.isAutoStartingSession = false
        }
        defer { try? store.destroy() }

        // GIVEN a request with response body stored
        date = Date().addingTimeInterval(-1000)
        let responseData = "body".data(using: .utf8)!
        store.startSession(.init(id: UUID(), startDate: date), info: .make())
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted1")!), response: nil, error: nil, data: responseData)
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted2")!), response: nil, error: nil, data: responseData)

        // ASSERT
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
        XCTAssertEqual(try store.backgroundContext.first(LoggerBlobHandleEntity.self)?.data, responseData)

        // WHEN
        date = Date()
        store.syncSweep()

        // THEN associated data is deleted
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 0)
    }

    func testMaxAgeSweepBlobIsKeptIfOnlyOneReferencingEntityIsDeleted() throws {
        // GIVEN the store with 5 minute max age
        let store = makeStore {
            $0.maxAge = 300
            $0.isAutoStartingSession = false
        }
        defer { try? store.destroy() }

        // GIVEN a request with response body stored
        date = Date().addingTimeInterval(-1000)
        let responseData = "body".data(using: .utf8)!
        store.startSession(.init(id: UUID(), startDate: date), info: .make())
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted")!), response: nil, error: nil, data: responseData)

        // GIVEN a request that's not deleted
        date = Date()
        store.startSession(.init(id: UUID(), startDate: date), info: .make())
        store.storeRequest(URLRequest(url: URL(string: "example.com/kept")!), response: nil, error: nil, data: responseData)

        // ASSERT
        XCTAssertEqual(try store.backgroundContext.count(for: NetworkTaskEntity.self), 2)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
        XCTAssertEqual(try store.backgroundContext.first(LoggerBlobHandleEntity.self)?.data, responseData)

        // WHEN
        date = Date()
        store.syncSweep()

        // THEN associated data is deleted
        XCTAssertEqual(try store.backgroundContext.count(for: NetworkTaskEntity.self), 1)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
    }

    func testBlobSizeLimitSweep() throws {
        // GIVEN store with blob size limit
        let store = makeStore {
            $0.maxAge = 300
            $0.isBlobCompressionEnabled = false
            $0.sizeLimit = 700 // will trigger sweep
            $0.expectedBlobRatio = 1.0
            $0.trimRatio = 0.5 // will remove items until 350 bytes are used
        }
        defer { try? store.destroy() }

        let now = Date()

        func storeRequest(id: String, offset: TimeInterval) {
            date = now.addingTimeInterval(offset)
            // Make sure data doesn't get deduplicated
            let data = Data(count: 300) + id.data(using: .utf8)!

            store.storeRequest(URLRequest(url: URL(string: "example.com/\(id)")!), response: nil, error: nil, data: data)
        }

        storeRequest(id: "1", offset: -100)
        storeRequest(id: "2", offset: 0)
        storeRequest(id: "3", offset: -200)

        // ASSERT
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 3)

        // WHEN
        store.syncSweep()

        // THEN
        let tasks = try store.backgroundContext.fetch(NetworkTaskEntity.self)
        XCTAssertEqual(tasks.count, 3) // Keeps the requests
        XCTAssertEqual(tasks.compactMap(\.responseBody).count, 1)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
    }

    func testBlobSizeLimitSweepLargeBlob() throws {
        // GIVEN store with blob size limit
        let store = makeStore {
            $0.isBlobCompressionEnabled = false
            $0.sizeLimit = 100 // will trigger sweep
            $0.expectedBlobRatio = 1.0
        }
        defer { try? store.destroy() }

        let responseData = Data(count: 256 * 1024)
        store.storeRequest(URLRequest(url: URL(string: "example.com/1")!), response: nil, error: nil, data: responseData)

        // ASSERT it's stored in a file system
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
        let request = try store.backgroundContext.first(NetworkTaskEntity.self)
        let key = try XCTUnwrap(request?.responseBody?.key)
        XCTAssertEqual(store.getBlobData(forKey: key.hexString), responseData)

        // WHEN
        store.syncSweep()

        // THEN the file is deleted from the file system
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 0)
        XCTAssertNil(store.getBlobData(forKey: key.hexString))
    }

    // MARK: - Migration

    func testMigrationFromVersion0_2ToLatest() throws {
        // GIVEN store created with the model from Pulse 0.2
        let storeURL = directory.url
            .appending(filename: UUID().uuidString)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true, attributes: nil)
        let databaseURL = storeURL
            .appending(filename: "logs.sqlite")
        try Resources.outdatedDatabase.write(to: databaseURL)

        // WHEN migrating to the store with the latest model
        let store = try LoggerStore(storeURL: storeURL, options: [.synchronous])
        defer { try? store.destroy() }

        // THEN automatic migration is performed and new field are populated with
        // empty values
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 0, "Previously recorded messages are going to be lost")

        // WHEN
        populate(store: store)

        // THEN can write new messages
        XCTAssertEqual(try store.allMessages().count, 10)
    }

    // MARK: - Remove Session

    func testRemoveSessions() throws {
        // GIVEN
        populate(store: store)
        let sessions = try store.viewContext.fetch(LoggerSessionEntity.self)

        // WHEN
        store.removeSessions(withIDs: Set(sessions.map(\.id)))

        // THEN
        XCTAssertEqual(try store.viewContext.fetch(LoggerSessionEntity.self).count, 0)
        XCTAssertEqual(try store.allMessages().count, 0)
        XCTAssertEqual(try store.allTasks().count, 0)
    }

    // MARK: - Remove All

    func testRemoveAll() throws {
        // GIVEN
        populate(store: store)
        store.storeMessage(label: "with meta", level: .debug, message: "test", metadata: ["hey": .string("this is meta yo")], file: #file, function: #function, line: #line)

        let context = store.viewContext
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 11)
        XCTAssertEqual(try context.count(for: NetworkTaskEntity.self), 3)
        XCTAssertEqual(try context.count(for: NetworkRequestEntity.self), 6)
        XCTAssertEqual(try context.count(for: NetworkResponseEntity.self), 5)
        XCTAssertEqual(try context.count(for: NetworkTransactionMetricsEntity.self), 3)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 3)

        // WHEN
        store.removeAll()

        // THEN both message and metadata are removed
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 0)
        XCTAssertEqual(try context.count(for: NetworkTaskEntity.self), 0)
        XCTAssertEqual(try context.count(for: NetworkRequestEntity.self), 0)
        XCTAssertEqual(try context.count(for: NetworkResponseEntity.self), 0)
        XCTAssertEqual(try context.count(for: NetworkTransactionMetricsEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)
    }

    func testRemoveAllWithLargeBlob() throws {
        // GIVEN large blob
        let store = makeStore {
            $0.isBlobCompressionEnabled = false
        }
        defer { try? store.destroy() }

        let responseData = Data(count: 256 * 1024)
        store.storeRequest(URLRequest(url: URL(string: "example.com/1")!), response: nil, error: nil, data: responseData)

        // ASSERT it's stored in a file system
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
        let request = try store.backgroundContext.first(NetworkTaskEntity.self)
        let key = try XCTUnwrap(request?.responseBody?.key)
        XCTAssertEqual(store.getBlobData(forKey: key.hexString), responseData)

        // WHEN
        store.removeAll()

        // THEN the file is deleted from the file system
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 0)
        XCTAssertNil(store.getBlobData(forKey: key.hexString))

        // WHEN store new files after removal
        store.storeRequest(URLRequest(url: URL(string: "example.com/1")!), response: nil, error: nil, data: responseData)

        // THEN you can store more files after removal
        XCTAssertEqual(store.getBlobData(forKey: key.hexString), responseData)
    }

    // MARK: - Store Request

    func testStoreRequest() throws {
        // WHEN
        populate(store: store)

        // THEN
        let request = try XCTUnwrap(store.viewContext.first(NetworkTaskEntity.self) {
            $0.predicate = NSPredicate(format: "url == %@", "https://github.com/login")
        })

        XCTAssertEqual(request.url, "https://github.com/login")
        XCTAssertEqual(request.host, "github.com")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.type, .dataTask)
        XCTAssertEqual(request.statusCode, 200)
        XCTAssertEqual(request.state, .success)
        XCTAssertEqual(request.isFromCache, false)
        XCTAssertEqual(request.redirectCount, 0)

        // Details
        XCTAssertEqual(request.originalRequest?.url, "https://github.com/login")
    }

    // MARK: - Image Support

#if os(iOS) || os(visionOS)
    func testImageThumbnailsAreStored() throws {
        // GIVEN
        let image = try makeMockImage()
        XCTAssertEqual(image.size, CGSize(width: 2048, height: 2048))
        let imageData = try XCTUnwrap(image.pngData())

        // WHEN
        let url = try XCTUnwrap(URL(string: "https://example.com/image"))

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "http/2.0", headerFields: [
            "Content-Type": "image/png"
        ])

        store.storeRequest(URLRequest(url: url), response: response, error: nil, data: imageData)

        // THEN
        let request = try XCTUnwrap(try store.backgroundContext.first(NetworkTaskEntity.self))
        let processedData = try XCTUnwrap(request.responseBody?.data)
        let thumbnail = try XCTUnwrap(UIImage(data: processedData))
        XCTAssertEqual(thumbnail.size, CGSize(width: 512, height: 512))

        // THEN original image size saved
        let metadata = try XCTUnwrap(request.metadata)
        XCTAssertEqual(metadata["ResponsePixelWidth"].flatMap { Int($0) }, 2048)
        XCTAssertEqual(metadata["ResponsePixelHeight"].flatMap { Int($0) }, 2048)
    }

    private func makeMockImage() throws -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 2048, height: 2048), true, 1)
        let context = try XCTUnwrap(UIGraphicsGetCurrentContext())

        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2048, height: 2048))

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return try XCTUnwrap(image)
    }
#endif

    // MARK: - Info

    func testGetStoreInfo() throws {
        // GIVEN
        populate(store: store)

        // WHEN
        let info = try store.info()

        // THEN
        XCTAssertEqual(info.storeVersion, "3.6.0")
        XCTAssertEqual(info.messageCount, 7)
        XCTAssertEqual(info.taskCount, 3)
        XCTAssertEqual(info.blobCount, 3)
    }

    // MARK: - Measure Export Speed & Size

    func testMeasureExportSize() async throws {
        // GIVEN
        let storeURL = try makePulsePackage()

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { try? store.destroy() }

        let copyURL = directory.url.appending(filename: "compressed.pulse")
        let start = benchmarkStart()
        try await store.export(to: copyURL)
        benchmarkEnd(start, title: "archive")

        let size = (try Files.attributesOfItem(atPath: copyURL.path)[.size] as? Int64) ?? 0
        print("Package: \(try storeURL.directoryTotalSize()). Archive: \(size)")
    }

    func _testMeasureExportSizeLarge() async throws {
        // GIVEN
        let store = makeStore {
            // Thumbnail generation significantly impacts the right speed
            $0.isStoringOnlyImageThumbnails = false
        }
        defer { try? store.destroy() }

        benchmark(title: "populate") {
            for _ in 0..<1000 {
                populate(store: store)
            }
        }

        let copyURL = directory.url.appending(filename: "compressed.pulse")
        let start = benchmarkStart()
        try await store.export(to: copyURL)
        benchmarkEnd(start, title: "archive")

        let size = (try Files.attributesOfItem(atPath: copyURL.path)[.size] as? Int64) ?? 0
        let compressed = try Data(contentsOf: copyURL).compressed()
        print("Package: \(try store.storeURL.directoryTotalSize())\nArchive: \(size) (\(compressed) compressed)")

        let info = try benchmark(title: "Open") {
            try LoggerStore(storeURL: copyURL)
        }
        XCTAssertEqual(try info.viewContext.count(for: NetworkRequestEntity.self), 6000)
        XCTAssertEqual(try info.viewContext.count(for: NetworkResponseEntity.self), 5000)
        XCTAssertEqual(try info.viewContext.count(for: LoggerMessageEntity.self), 10000)
    }
}
