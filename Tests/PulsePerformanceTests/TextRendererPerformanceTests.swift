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
}
