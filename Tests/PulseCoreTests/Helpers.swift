// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
@testable import PulseCore

extension LoggerStore {
    func removeStores() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }
    }
}

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
