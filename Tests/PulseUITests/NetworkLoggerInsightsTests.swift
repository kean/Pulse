// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

final class NetworkLoggerInsightsTests: ConsoleTestCase {
    func testInsightsTransferSize() throws {
        // GIVEN
        let tasks = try store.allTasks()
        let insights = NetworkLoggerInsights(tasks)

        // THEN
        let transferSize = insights.transferSize

        XCTAssertEqual(transferSize.totalBytesSent, 21853050)
        XCTAssertEqual(transferSize.requestHeaderBytesSent, 1257)
        XCTAssertEqual(transferSize.requestBodyBytesBeforeEncoding, 21851813)
        XCTAssertEqual(transferSize.requestBodyBytesSent, 21851793)

        XCTAssertEqual(transferSize.totalBytesReceived, 6699724)
        XCTAssertEqual(transferSize.responseHeaderBytesReceived, 2066)
        XCTAssertEqual(transferSize.responseBodyBytesAfterDecoding, 6698506)
        XCTAssertEqual(transferSize.responseBodyBytesReceived, 6697658)
    }
}
