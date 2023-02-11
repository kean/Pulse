// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

final class NetworkLoggerInsightsTests: ConsoleTestCase {
    func makeInsights() throws -> NetworkLoggerInsights {
        let tasks = try store.allTasks()
        return NetworkLoggerInsights(tasks)
    }

    func testTransferSize() throws {
        // GIVEN
        let insights = try makeInsights()
        let transferSize = insights.transferSize

        // THEN
        XCTAssertEqual(transferSize.totalBytesSent, 21853050)
        XCTAssertEqual(transferSize.requestHeaderBytesSent, 1257)
        XCTAssertEqual(transferSize.requestBodyBytesBeforeEncoding, 21851813)
        XCTAssertEqual(transferSize.requestBodyBytesSent, 21851793)

        XCTAssertEqual(transferSize.totalBytesReceived, 6699724)
        XCTAssertEqual(transferSize.responseHeaderBytesReceived, 2066)
        XCTAssertEqual(transferSize.responseBodyBytesAfterDecoding, 6698506)
        XCTAssertEqual(transferSize.responseBodyBytesReceived, 6697658)
    }

    func testDuration() throws {
        // GIVEN
        let insights = try makeInsights()
        let duration = insights.duration

        // THEN
        XCTAssertEqual(duration.median!, 0.52691, accuracy: 0.01)
        XCTAssertEqual(duration.maximum!, 4.46537, accuracy: 0.01)
        XCTAssertEqual(duration.minimum!, 0.2269, accuracy: 0.01)
        let durations = duration.topSlowestRequests.map { $0.1 }
        XCTAssertEqual(durations.sorted(by: { $0 > $1 }), durations)
    }

    func testRedirects() throws {
        // GIVEN
        let insights = try makeInsights()
        let redirects = insights.redirects

        // THEN
        XCTAssertEqual(redirects.count, 1)
        XCTAssertEqual(redirects.timeLost, 0.21282994747161865, accuracy: 0.01)
        XCTAssertEqual(redirects.taskIds.count, 1)
    }
}

#endif
