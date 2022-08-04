// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
@testable import PulseCore

final class LoggerStoreTests: XCTestCase {
    let directory = TemporaryDirectory()
    var storeURL: URL!
    var date: Date = Date()

    var store: LoggerStore!

    override func setUp() {
        super.setUp()

        try? FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true, attributes: nil)
        storeURL = directory.url.appendingPathComponent("test-store")
        store = try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous])
    }

    override func tearDown() {
        super.tearDown()

        store.destroyStores()
        directory.remove()

        try? FileManager.default.removeItem(at: URL.temp)
    }

    // MARK: - Init

    func testInitStoreMissing() throws {
        // GIVEN
        let storeURL = directory.url.appendingPathComponent(UUID().uuidString)

        // WHEN/THEN
        XCTAssertThrowsError(try LoggerStore(storeURL: storeURL))
    }

    func testInitCreateStoreURL() throws {
        // GIVEN
        let storeURL = directory.url.appendingPathComponent(UUID().uuidString)
        let options: LoggerStore.Options = [.create, .synchronous]

        // WHEN
        let firstStore = try LoggerStore(storeURL: storeURL, options: options)
        XCTAssertEqual(firstStore.manifest.version, LoggerStore.Manifest.currentVersion)
        try firstStore.populate()

        let secondStore = try LoggerStore(storeURL: storeURL)
        XCTAssertEqual(secondStore.manifest.version, LoggerStore.Manifest.currentVersion)

        // THEN data is persisted
        XCTAssertEqual(try secondStore.allMessages().count, 1)

        // CLEANUP
        firstStore.destroyStores()
        secondStore.destroyStores()
    }

    func testInitCreateStoreIntermediateDirectoryMissing() throws {
        // GIVEN
        let storeURL = directory.url
            .appendingPathComponent(UUID().uuidString, isDirectory: false) // Missing directory
            .appendingPathComponent(UUID().uuidString)
        let options: LoggerStore.Options = [.create]

        // WHEN/THEN
        XCTAssertThrowsError(try LoggerStore(storeURL: storeURL, options: options))
    }

    func testInitStoreWithURL() throws {
        // GIVEN
        try store.populate()
        XCTAssertEqual(try store.allMessages().count, 1)

        let originalStore = store
        store.removeStores()

        // WHEN loading the store with the same url
        store = try LoggerStore(storeURL: storeURL)

        // THEN data is persisted
        XCTAssertEqual(try store.allMessages().count, 1)

        // CLEANUP
        originalStore?.destroyStores()
    }

    func testInitWithArchiveURL() throws {
        // GIVEN
        let storeURL = directory.url.appendingPathComponent("logs-archive-v2.pulse")
        try Resources.pulseArchive.write(to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { store.destroyStores() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 15)
        XCTAssertEqual(try store.viewContext.count(for: LoggerNetworkRequestEntity.self), 8)
        XCTAssertEqual(try store.viewContext.count(for: LoggerMetadataEntity.self), 1)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 7)

        // THEN data stored in external storage also persist
        let request = try XCTUnwrap(store.viewContext.first(LoggerNetworkRequestEntity.self) {
            $0.predicate = NSPredicate(format: "url == %@", "https://github.com/repos")
        })
        XCTAssertEqual(request.responseBodySize, 165061)
        XCTAssertEqual(request.responseBody?.data.count, 165061)
    }

    func testInitWithArchiveURLNoExtension() throws {
        // GIVEN
        let storeURL = directory.url.appendingPathComponent("logs-archive-v2")
        try Resources.pulseArchive.write(to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { store.destroyStores() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 15)
        XCTAssertEqual(try store.viewContext.count(for: LoggerNetworkRequestEntity.self), 8)
        XCTAssertEqual(try store.viewContext.count(for: LoggerMetadataEntity.self), 1)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 7)

        // THEN data stored in external storage also persist
        let request = try XCTUnwrap(store.viewContext.first(LoggerNetworkRequestEntity.self) {
            $0.predicate = NSPredicate(format: "url == %@", "https://github.com/repos")
        })
        XCTAssertEqual(request.responseBodySize, 165061)
        XCTAssertEqual(request.responseBody?.data.count, 165061)
    }

    func testInitWithPackageURL() throws {
        // GIVEN
        let archiveURL = directory.url.appendingPathComponent(UUID().uuidString)
        try Resources.pulseArchive.write(to: archiveURL)
        let storeURL = directory.url.appendingPathComponent(UUID().uuidString)
        try FileManager.default.unzipItem(at: archiveURL, to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { store.destroyStores() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 15)
        XCTAssertEqual(try store.viewContext.count(for: LoggerNetworkRequestEntity.self), 8)
        XCTAssertEqual(try store.viewContext.count(for: LoggerMetadataEntity.self), 1)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 7)

        // THEN data stored in external storage also persist
        let request = try XCTUnwrap(store.viewContext.first(LoggerNetworkRequestEntity.self) {
            $0.predicate = NSPredicate(format: "url == %@", "https://github.com/repos")
        })
        XCTAssertEqual(request.responseBodySize, 165061)
        XCTAssertEqual(request.responseBody?.data.count, 165061)
    }

    func testInitWithPackageURLNoExtension() throws {
        // GIVEN
        let archiveURL = directory.url.appendingPathComponent(UUID().uuidString)
        try Resources.pulseArchive.write(to: archiveURL)
        let storeURL = directory.url.appendingPathComponent(UUID().uuidString)
        try FileManager.default.unzipItem(at: archiveURL, to: storeURL)

        // WHEN
        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        defer { store.destroyStores() }

        // THEN entities can be opened
        XCTAssertEqual(try store.viewContext.count(for: LoggerMessageEntity.self), 15)
        XCTAssertEqual(try store.viewContext.count(for: LoggerNetworkRequestEntity.self), 8)
        XCTAssertEqual(try store.viewContext.count(for: LoggerMetadataEntity.self), 1)
        XCTAssertEqual(try store.viewContext.count(for: LoggerBlobHandleEntity.self), 7)

        // THEN data stored in external storage also persist
        let request = try XCTUnwrap(store.viewContext.first(LoggerNetworkRequestEntity.self) {
            $0.predicate = NSPredicate(format: "url == %@", "https://github.com/repos")
        })
        XCTAssertEqual(request.responseBodySize, 165061)
        XCTAssertEqual(request.responseBody?.data.count, 165061)
    }

    // MARK: - Copy (Directory)

    func testCopyDirectory() throws {
        // GIVEN
        populate2(store: store)

        let copyURL = directory.url.appendingPathComponent("copy.pulse")

        // WHEN
        try store.copy(to: copyURL)

        // THEN
        store.removeStores()

        // THEN
        let copy = try LoggerStore(storeURL: copyURL)
        defer { copy.destroyStores() }

        XCTAssertEqual(try copy.allMessages().count, 10)
        XCTAssertEqual(try copy.allNetworkRequests().count, 3)
    }

    func testCopyToNonExistingFolder() throws {
        // GIVEN
        populate2(store: store)

        let invalidURL = directory.url
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("copy.pulse")

        // WHEN/THEN
        XCTAssertThrowsError(try store.copy(to: invalidURL))
    }

    func testCopyButFileExists() throws {
        // GIVEN
        populate2(store: store)

        let copyURL = directory.url
            .appendingPathComponent("copy.pulse")

        try store.copy(to: copyURL)

        // WHEN/THEN
        XCTAssertThrowsError(try store.copy(to: copyURL))
    }

    // MARK: - Copy (File)

    func testCopyFile() throws {
        // GIVEN
        let storeURL = directory.url.appendingPathComponent("logs-archive-v2.pulse")
        try Resources.pulseArchive.write(to: storeURL)

        let store = try XCTUnwrap(LoggerStore(storeURL: storeURL))
        let copyURL = directory.url.appendingPathComponent("copy.pulse")

        // WHEN
        try store.copy(to: copyURL)

        // THEN
        let copy = try LoggerStore(storeURL: copyURL)
        defer { copy.destroyStores() }

        XCTAssertEqual(try copy.allMessages().count, 15)
        XCTAssertEqual(try copy.allNetworkRequests().count, 8)
    }

    // MARK: - File (Readonly)

    // TODO: this type of store is no longer immuatble
    func _testOpenFileDatabaseImmutable() throws {
        // GIVEN
        let storeURL = directory.url.appendingPathComponent("logs-archive-v2.pulse")
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

    func testSizeLimit() throws {
        let store = try! LoggerStore(
            storeURL: directory.url.appendingPathComponent(UUID().uuidString),
            options: [.create, .synchronous],
            configuration: .init(databaseSizeLimit: 5000)
        )
        defer { store.destroyStores() }

        // GIVEN
        let context = store.viewContext

        store.storeRequest(URLRequest(url: URL(string: "example.com/delete-this")!), response: nil, error: nil, data: "hello".data(using: .utf8))
        for index in 1...500 {
            store.storeMessage(label: "default", level: .debug, message: "\(index)", metadata: {
                index % 50 == 0 ? ["key": .stringConvertible(index)] : nil
            }())
        }

        let copyURL = directory.url
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("pulse")
        try store.copy(to: copyURL)

        // SANITY
        var messages = try store.allMessages()
        XCTAssertEqual(messages.count, 501)
        XCTAssertEqual(messages.last?.text, "500")

        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 501)
        XCTAssertEqual(try context.count(for: LoggerMetadataEntity.self), 10)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestEntity.self), 1)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 1)
        context.reset()

        // WHEN
        store.syncSweep()

        // THEN
        let copyURL2 = directory.url
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
            .appendingPathExtension("pulse")
        try store.copy(to: copyURL2)

        // THEN unwanted messages were removed
        messages = try context.fetch(LoggerMessageEntity.self)
        XCTAssertEqual(messages.count, 351)
        XCTAssertEqual(messages.last?.text, "500") // Latest stored

        // THEN metadata, network requests, blobs are removed
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 351)
        XCTAssertEqual(try context.count(for: LoggerMetadataEntity.self), 8)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)
    }

    func testMaxAgeSweep() throws {
        // GIVEN the store with 5 minute max age
        let store = makeStore {
            $0.maxAge = 300
        }
        defer { store.destroyStores() }

        // GIVEN some messages stored before the cutoff date
        date = Date().addingTimeInterval(-1000)
        store.storeMessage(label: "deleted", level: .debug, message: "test")
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted")!), response: nil, error: nil, data: nil)

        // GIVEN some messages stored after
        date = Date()
        store.storeMessage(label: "kept", level: .debug, message: "test")
        store.storeRequest(URLRequest(url: URL(string: "example.com/kept")!), response: nil, error: nil, data: nil)

        // ASSERT
        let context = store.backgroundContext
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 4)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestEntity.self), 2)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestDetailsEntity.self), 2)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)
        context.reset()

        // WHEN
        store.syncSweep()

        // THEN
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 2)
        XCTAssertEqual(try context.count(for: LoggerMetadataEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestEntity.self), 1)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestDetailsEntity.self), 1)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestProgressEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)

        XCTAssertEqual(try store.allMessages().first?.label, "kept")
        XCTAssertEqual(try store.allNetworkRequests().first?.url, "example.com/kept")
    }

    func testMaxAgeSweepBlobIsDeletedWhenEntityIsDeleted() throws {
        // GIVEN the store with 5 minute max age
        let store = makeStore {
            $0.maxAge = 300
        }
        defer { store.destroyStores() }

        // GIVEN a request with response body stored
        date = Date().addingTimeInterval(-1000)
        let responseData = "body".data(using: .utf8)!
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted")!), response: nil, error: nil, data: responseData)

        // ASSERT
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
        XCTAssertEqual(try store.backgroundContext.first(LoggerBlobHandleEntity.self)?.data, responseData)

        // WHEN
        date = Date()
        store.syncSweep()

        // THEN associated data is deleted
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerMessageEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerMetadataEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerNetworkRequestEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerNetworkRequestDetailsEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerNetworkRequestProgressEntity.self), 0)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 0)
    }

    func testMaxAgeSweepBlobIsDeletedWhenBothEntitiesReferencingItAre() throws {
        // GIVEN the store with 5 minute max age
        let store = makeStore {
            $0.maxAge = 300
        }
        defer { store.destroyStores() }

        // GIVEN a request with response body stored
        date = Date().addingTimeInterval(-1000)
        let responseData = "body".data(using: .utf8)!
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
        }
        defer { store.destroyStores() }

        // GIVEN a request with response body stored
        date = Date().addingTimeInterval(-1000)
        let responseData = "body".data(using: .utf8)!
        store.storeRequest(URLRequest(url: URL(string: "example.com/deleted")!), response: nil, error: nil, data: responseData)

        // GIVEN a request that's not deleted
        date = Date()
        store.storeRequest(URLRequest(url: URL(string: "example.com/kept")!), response: nil, error: nil, data: responseData)

        // ASSERT
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerNetworkRequestEntity.fetchRequest()), 2)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
        XCTAssertEqual(try store.backgroundContext.first(LoggerBlobHandleEntity.self)?.data, responseData)

        // WHEN
        date = Date()
        store.syncSweep()

        // THEN associated data is deleted
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerNetworkRequestEntity.self), 1)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
    }

    func testBlobSizeLimitSweep() throws {
        // GIVEN store with blob size limit
        let store = makeStore {
            $0.maxAge = 300
            $0.blobsSizeLimit = 700 // will trigger sweep
            $0.trimRatio = 0.5 // will remove items until 350 bytes are used
        }

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
        let requests = try store.backgroundContext.fetch(LoggerNetworkRequestEntity.self)
        XCTAssertEqual(requests.count, 3) // Keeps the requests
        XCTAssertEqual(requests.compactMap(\.responseBody).count, 1)
        XCTAssertEqual(try store.backgroundContext.count(for: LoggerBlobHandleEntity.self), 1)
    }

    // MARK: - Migration

    func testMigrationFromVersion0_2ToLatest() throws {
        // GIVEN store created with the model from Pulse 0.2
        let storeURL = directory.url
            .appendingPathComponent(UUID().uuidString, isDirectory: false)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true, attributes: nil)
        let databaseURL = storeURL
            .appendingPathComponent("logs.sqlite", isDirectory: false)
        try Resources.outdatedDatabase.write(to: databaseURL)

        // WHEN migrating to the store with the latest model
        let store = try LoggerStore(storeURL: storeURL, options: [.synchronous])
        defer { store.destroyStores() }

        // THEN automatic migration is performed and new field are populated with
        // empty values
        let messages = try store.allMessages()
        XCTAssertEqual(messages.count, 0, "Previously recorded messages are going to be lost")

        // WHEN
        try store.populate()

        // THEN can write new messages
        XCTAssertEqual(try store.allMessages().count, 1)
    }

    // MARK: - Remove Messages

    func testRemoveAllMessages() throws {
        // GIVEN
        populate2(store: store)
        store.storeMessage(label: "with meta", level: .debug, message: "test", metadata: ["hey": .string("this is meta yo")], file: #file, function: #function, line: #line)

        let context = store.viewContext
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 11)
        XCTAssertEqual(try context.count(for: LoggerMetadataEntity.self), 1)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestEntity.self), 3)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestDetailsEntity.self), 3)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 3)

        // WHEN
        store.removeAll()

        // THEN both message and metadata are removed
        XCTAssertEqual(try context.count(for: LoggerMessageEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerMetadataEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerNetworkRequestDetailsEntity.self), 0)
        XCTAssertEqual(try context.count(for: LoggerBlobHandleEntity.self), 0)
    }

    // MARK: - Image Support

#if os(iOS)
    func testImageThumbnailsAreStored() throws {
        // GIVEN
        let image = try makeMockImage()
        XCTAssertEqual(image.size, CGSize(width: 2048, height: 2048))
        let imageData = try XCTUnwrap(image.pngData())

        // WHEN
        let url = try XCTUnwrap(URL(string: "https://example.com/image"))
        let taskId = UUID()

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "http/2.0", headerFields: [
            "Content-Type": "image/png"
        ])

        store.storeRequest(taskId: taskId, taskType: .dataTask, request: URLRequest(url: url), response: response, error: nil, data: imageData, metrics: nil)

        // THEN
        let request = try XCTUnwrap(try store.backgroundContext.first(LoggerNetworkRequestEntity.self))
        let processedData = try XCTUnwrap(request.responseBody?.data)
        let thumbnail = try XCTUnwrap(UIImage(data: processedData))
        XCTAssertEqual(thumbnail.size, CGSize(width: 256, height: 256))

        // THEN original image size saved
        let metadata = try XCTUnwrap(JSONDecoder().decode([String: String].self, from: request.details.metadata ?? Data()))
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

    // MARK: - Helpers

    private func makeStore(_ closure: (inout LoggerStore.Configuration) -> Void) -> LoggerStore {
        var configuration = LoggerStore.Configuration()
        configuration.makeCurrentDate = { [unowned self] in self.date }
        closure(&configuration)

        return try! LoggerStore(
            storeURL: directory.url.appendingPathComponent(UUID().uuidString),
            options: [.create, .synchronous],
            configuration: configuration
        )
    }
}

private extension LoggerStore {
    func populate() throws {
        storeMessage(label: "default", level: .debug, message: "Some message", metadata: [
            "system": .string("application")
        ])
    }
}
