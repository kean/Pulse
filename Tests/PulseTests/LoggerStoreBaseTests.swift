// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
import Combine
@testable import Pulse

class LoggerStoreBaseTests: XCTestCase {
    let directory = TemporaryDirectory()
    var storeURL: URL!
    var date: Date = Date()

    var store: LoggerStore!
    var cancellables: [AnyCancellable] = []

    override func setUp() {
        super.setUp()

        try? FileManager.default.createDirectory(at: directory.url, withIntermediateDirectories: true, attributes: nil)
        storeURL = directory.url.appending(filename: "test-store")
    }

    override func tearDown() {
        super.tearDown()

        try? store.destroy()
        directory.remove()

        try? FileManager.default.removeItem(at: URL.temp)
    }

    func makeStore(options: LoggerStore.Options =  [.create, .synchronous], _ closure: (inout LoggerStore.Configuration) -> Void = { _ in }) -> LoggerStore {
        var configuration = LoggerStore.Configuration()
        configuration.makeCurrentDate = { [unowned self] in self.date }
        closure(&configuration)

        return try! LoggerStore(
            storeURL: directory.url.appending(filename: UUID().uuidString),
            options: options,
            configuration: configuration
        )
    }

    func makePulsePackage() throws -> URL {
        let storeURL = directory.url.appending(filename: UUID().uuidString)
        let store = try LoggerStore(storeURL: storeURL, options: [.create, .synchronous])
        populate(store: store)
        try? store.close()
        return storeURL
    }
}
