// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

final class InsightsViewModelTests: ConsoleTestCase {
    var sut: InsightsViewModel!

    var criteria: ConsoleSearchCriteriaViewModel!

    override func setUp() {
        super.setUp()

        reset()
    }

    func reset() {
        criteria = ConsoleSearchCriteriaViewModel(criteria: .init(), index: .init(store: store))

        sut = InsightsViewModel(store: store, context: .init(), criteria: criteria)
        sut.isViewVisible = true
    }

    func testInsightsLoaded() {
        XCTAssertEqual(sut.insights.transferSize.totalBytesSent, 21853050)
        XCTAssertEqual(sut.insights.transferSize.totalBytesReceived, 6699724)
    }

    func testInsertTask() {
        let expecation = self.expectation(description: "insightsUpdated")
        sut.$insights.dropFirst().sink { _ in expecation.fulfill() }.store(in: &cancellables)

        XCTAssertEqual(sut.insights.duration.values.count, 8)

        // WHEN
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let date = Date()
        store.handle(.networkTaskCompleted(.init(
            taskId: UUID(),
            taskType: .dataTask,
            createdAt: date,
            originalRequest: .init(request),
            currentRequest: .init(request),
            response: nil,
            error: nil,
            requestBody: Data(count: 1000),
            responseBody: nil,
            metrics: .init(
                taskInterval: DateInterval(start: date, end: date.addingTimeInterval(1)),
                redirectCount: 0,
                transactions: []
            ),
            sessionID: store.sessionID
        )))

        // THEN
        wait(for: [expecation], timeout: 1)
        XCTAssertEqual(sut.insights.duration.values.count, 9)
    }
}

#endif
