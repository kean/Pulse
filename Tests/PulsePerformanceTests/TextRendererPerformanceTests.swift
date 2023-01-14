// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Pulse
import PulseUI

final class TextRendererTestsTests: XCTestCase {
    func testAttributedStringGenerationPerformance() throws {
        let entities = try LoggerStore.mock.allMessages()
        measure {
            for _ in 0..<10 {
                let expecation = self.expectation(description: "dsd")
                let _ = TextRendererTests.share(entities, store: .mock) {
                    expecation.fulfill()
                }
                wait(for: [expecation], timeout: 2)
            }
        }
    }
}

@discardableResult
private func benchmark<T>(title: String, operation: () throws -> T) rethrows -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let value = try operation()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Time elapsed for \(title): \(timeElapsed * 1000.0) ms.")
    return value
}
