// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if DEBUG

enum MockStoreConfiguration {
    /// Delay logs with random intervals.
    static let isDelayingLogs = true
    /// Add the same logs indefinitely with an interval.
    static let isIndefinite = false
    /// If true uses the default store that support remote logging.
    static let isUsingDefaultStore = true
}

#endif
