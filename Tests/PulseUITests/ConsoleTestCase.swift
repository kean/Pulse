// The MIT License (MIT)
//
// Copyright (c) 2020-2023 Alexander Grebenyuk (github.com/kean).

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

class ConsoleTestCase: XCTestCase {
    var store: LoggerStore!
    let directory = TemporaryDirectory()
    var cancellables: [AnyCancellable] = []

    override func setUp() {
        super.setUp()

        let storeURL = directory.url.appendingPathComponent("\(UUID().uuidString).pulse")
        store = try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous])
        store.populate()
    }

    override func tearDown() {
        super.tearDown()

        try? store.destroy()
        directory.remove()
    }
}
