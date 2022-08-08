// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
@testable import Pulse

struct TemporaryDirectory {
    let url: URL

    static var isFirstRun = true

    init() {
        let rootTempURL = Files.temporaryDirectory
            .appending(directory: "com.github.kean.logger-testing")

        if TemporaryDirectory.isFirstRun {
            TemporaryDirectory.isFirstRun = false
            try? Files.removeItem(at: rootTempURL)
        }

        url = rootTempURL.appending(directory: UUID().uuidString)
        try? Files.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
