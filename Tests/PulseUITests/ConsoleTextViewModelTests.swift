// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import XCTest
import Combine
@testable import Pulse
@testable import PulseUI

final class ConsoleTextViewModelTests: ConsoleTestCase {
    var sut: ConsoleTextViewModel!

    var criteria: ConsoleSearchCriteriaViewModel!
    var router: ConsoleRouter!

    override func setUp() {
        super.setUp()

        reset()
    }

    func reset() {
        criteria = ConsoleSearchCriteriaViewModel(criteria: .init(), index: .init(store: store))
        router = ConsoleRouter()

        sut = ConsoleTextViewModel(store: store, source: .store, criteria: criteria, router: router)
        sut.isViewVisible = true
    }
}

#endif
