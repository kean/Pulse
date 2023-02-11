// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

final class ShareStoreViewModelTests: ConsoleTestCase {
    var sut: ShareStoreViewModel!

    override func setUp() {
        super.setUp()

        sut = ShareStoreViewModel()
    }

    func testSharingMessagesFromCurrentSession() throws {
        // GIVEN
        sut.display(store)

        let expectation = self.expectation(description: "outputPrepared")
        // First for the default options and second for the currentSession
        expectation.expectedFulfillmentCount = 2
        sut.$sharedContents.dropFirst().sink { value in
            if value != nil {
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        // WHEN
        sut.timeRange = .currentSession

        // THEN
        wait(for: [expectation], timeout: 2)
        let content = try XCTUnwrap(sut.sharedContents)
        XCTAssertNotNil(content.item)
    }
}
