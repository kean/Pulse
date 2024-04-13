// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
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
