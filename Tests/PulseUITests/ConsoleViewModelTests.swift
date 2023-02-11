// The MIT License (MIT)
//
// Copyright (c) 2020-2022 Alexander Grebenyuk (github.com/kean).

import XCTest
@testable import Pulse
@testable import PulseUI

final class ConsoleViewModelTests: ConsoleTestCase {
    var source: ConsoleSource = .store
    var mode: ConsoleMode = .all
    var isOnlyNetwork = false
    var options = ConsoleListOptions()

    var sut: ConsoleViewModel!

    override func setUp() {
        super.setUp()

        reset()
    }

    private func reset() {
        sut = ConsoleViewModel(store: store, source: source, mode: mode, isOnlyNetwork: isOnlyNetwork)
    }
}
