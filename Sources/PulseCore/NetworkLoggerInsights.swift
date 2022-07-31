// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine

/// Collects insights about the current session.
public final class NetworkLoggerInsights {
    private var cancellables: [AnyCancellable] = []

    private(set) public var transferSize = NetworkLoggerMetrics.TransferSize()
    private(set) public var duration = RequestsDuration()

    public let didUpdate = PassthroughSubject<Void, Never>()

    /// Registers a given store. More than one store can be reigstered.
    public func register(store: LoggerStore) {
        store.events.sink { [weak self] in
            self?.process(event: $0)
        }.store(in: &cancellables)
    }

    // TODO: perform calculations in background
    private func process(event: LoggerStoreEvent) {
        switch event {
        case .messageStored: break
        case .networkTaskCreated: break
        case .networkTaskProgressUpdated: break
        case .networkTaskCompleted(let event): process(event: event)
        }
    }

    private func process(event: LoggerStoreEvent.NetworkTaskCompleted) {
        if let metrics = event.metrics {
            transferSize = transferSize.merging(metrics.transferSize)
        }
        if let metrics = event.metrics {
            duration.insert(duration: TimeInterval(metrics.taskInterval.duration))
        }
        didUpdate.send(())
    }

    // TODO: Add a way to reset

    // - Redirects (Bad) + how much time can save total
    // - Slow response (Warning)
    // - Errors

    public struct RequestsDuration {
        public var median: TimeInterval?
        public var maximum: TimeInterval?
        public var minimum: TimeInterval?

        /// Sorted list of all recoreded durations.
        public var durations: [TimeInterval] = []

        mutating func insert(duration: TimeInterval) {
            durations.insert(duration, at: insertionIndex(for: duration))
            median = durations[durations.count / 2]
            if let maximum = self.maximum {
                self.maximum = max(maximum, duration)
            } else {
                self.maximum = duration
            }
            if let minimum = self.minimum {
                self.minimum = min(minimum, duration)
            } else {
                self.minimum = duration
            }
        }

        private func insertionIndex(for duration: TimeInterval) -> Int {
            var lowerBound = 0
            var upperBound = durations.count
            while lowerBound < upperBound {
                let mid = lowerBound + (upperBound - lowerBound) / 2
                if durations[mid] == duration {
                    return mid
                } else if durations[mid] < duration {
                    lowerBound = mid + 1
                } else {
                    upperBound = mid
                }
            }
            return lowerBound
        }
    }
}
