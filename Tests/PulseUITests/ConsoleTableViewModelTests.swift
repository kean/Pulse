// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

final class ConsoleTableViewModelTests: ConsoleTestCase {
    var sut: ConsoleTableViewModel!

    var criteria: ConsoleSearchCriteriaViewModel!

    override func setUp() {
        super.setUp()

        reset()
    }

    func reset() {
        criteria = ConsoleSearchCriteriaViewModel(criteria: .init(), index: .init(store: store))

        sut = ConsoleTableViewModel(store: store, source: .store, criteria: criteria)
        sut.isViewVisible = true
    }

    // MARK: Ordering

    func testCustomSortDescriptor() {
        // WHEN
        sut.sort(using: [NSSortDescriptor(keyPath: \LoggerMessageEntity.level, ascending: true)])

        // THEN
        XCTAssertEqual(
            sut.entities,
            (sut.entities as! [LoggerMessageEntity]).sorted(by: { $0.level < $1.level })
        )
    }
}

#endif
