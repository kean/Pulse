// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

class ConsoleTestCase: XCTestCase {
    var store: LoggerStore!
    let directory = TemporaryDirectory()

    override func setUp() {
        super.setUp()

        let storeURL = directory.url.appending(filename: "\(UUID().uuidString).pulse")
        store = try! LoggerStore(storeURL: storeURL, options: [.create, .synchronous])
        store.populate()
    }

    override func tearDown() {
        super.tearDown()

        try? store.destroy()
        directory.remove()
    }
}
