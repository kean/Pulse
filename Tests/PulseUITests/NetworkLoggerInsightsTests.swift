// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
import Foundation
import CoreData
import Combine
@testable import PulseCore
@testable import PulseUI

final class NetworkLoggerInsightsTests: XCTestCase {
    private var cancellable: AnyCancellable?

    func testTransferSize() throws {
        // GIVEN
        let store = LoggerStore.mock
        let insights = try XCTUnwrap(store.insights)

        // THEN
        let expectation = self.expectation(description: "WillChange")
        expectation.expectedFulfillmentCount = 16
        cancellable = insights.objectWillChange.sink { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(insights.duration.durations.count, 8)
        XCTAssertEqual(insights.duration.durations.sorted(), insights.duration.durations)
    }
}
