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
                let _ = TextRendererTests.share(entities)
            }
        }
    }

    func testPlainTextConversion() throws {
        let entities = try LoggerStore.mock.allMessages()
        let string = TextRendererTests.share(entities)
        measure {
            for _ in 0..<1000 {
                let _ = TextRendererTests.plainText(from: string)
            }
        }
    }

    func testHTMLConversion() throws {
        let entities = try LoggerStore.mock.allMessages()
        let string = TextRendererTests.share(entities)
        measure {
            for _ in 0..<10 {
                let _ = try! TextRendererTests.html(from: string)
            }
        }
    }

#if os(iOS)
    func testPDFConverstion() throws {
        let entities = try LoggerStore.mock.allMessages()
        let string = TextRendererTests.share(entities)
        measure {
            for _ in 0..<1 {
                let _ = try! TextRendererTests.pdf(from: string)
            }
        }
    }
#endif

    // MARK: Big Store

    func testBigStoreAttributedString() throws {
        let url = try XCTUnwrap(Bundle(for: TextRendererTestsTests.self).url(forResource: "bigstore", withExtension: "pulse"))
        let store = try LoggerStore(storeURL: url)
        let entities = try store.allMessages()

        benchmark(title: "Entities -> NSAttributedString") {
            let _ = TextRendererTests.share(entities)
        }
    }

    func testBigStoreHTML() throws {
        let url = try XCTUnwrap(Bundle(for: TextRendererTestsTests.self).url(forResource: "bigstore", withExtension: "pulse"))
        let store = try LoggerStore(storeURL: url)
        let entities = try store.allMessages()

        let string = TextRendererTests.share(entities)

        benchmark(title: "NSAttributedString -> HTML") {
            let _ = try! TextRendererTests.html(from: string)
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
