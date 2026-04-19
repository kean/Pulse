// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

public struct TestTemporaryDirectory {
    public let url: URL

    public static var isFirstRun = true

    public init() {
        let rootTempURL = Files.temporaryDirectory
            .appending(directory: "com.github.kean.logger-testing")

        if TestTemporaryDirectory.isFirstRun {
            TestTemporaryDirectory.isFirstRun = false
            try? Files.removeItem(at: rootTempURL)
        }

        url = rootTempURL.appending(directory: UUID().uuidString)
        try? Files.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }

    public func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}

@discardableResult
public func benchmark<T>(title: String, operation: () throws -> T) rethrows -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let value = try operation()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Time elapsed for \(title): \(timeElapsed * 1000.0) ms.")
    return value
}

public func benchmarkStart() -> CFAbsoluteTime {
    CFAbsoluteTimeGetCurrent()
}

public func benchmarkEnd(_ startTime: CFAbsoluteTime, title: String) {
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Time elapsed for \(title): \(timeElapsed * 1000.0) ms.")
}
