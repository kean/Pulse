// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if DEBUG || PULSE_DEMO

enum MockStoreConfiguration {
    /// Delay logs with random intervals.
    static let isDelayingLogs = true
    /// Add the same logs indefinitely with an interval.
    static let isIndefinite = true
    /// If true uses the default store that support remote logging.
    static let isUsingDefaultStore = true
}

#endif
