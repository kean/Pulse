// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

#warning("TODO: remove this and make one instance of it")

#if DEBUG || PULSE_MOCK_INCLUDED

enum MockStoreConfiguration {
    static let isDelayingLogs = false
    static let isIndefinite = false
    static let isUsingDefaultStore = false
}

#endif
