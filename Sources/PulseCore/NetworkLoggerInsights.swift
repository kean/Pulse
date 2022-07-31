// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine

/// Collects insights about the current session.
public final class NetworkLoggerInsights {
    private var cancellables: [AnyCancellable] = []

    private(set) public var transferSize = NetworkLoggerMetrics.TransferSize()
    // TODO: Add separete per task type
    private(set) public var duration = RequestsDuration()

    public let didUpdate = PassthroughSubject<Void, Never>()

    private let queue = DispatchQueue(label: "com.githun.kean.network-logger-insights")

    /// Registers a given store. More than one store can be reigstered.
    public func register(store: LoggerStore) {
        store.events.receive(on: queue).sink { [weak self] in
            self?.process(event: $0)
        }.store(in: &cancellables)
    }

    private func process(event: LoggerStoreEvent) {
        switch event {
        case .messageStored: break
        case .networkTaskCreated: break
        case .networkTaskProgressUpdated: break
        case .networkTaskCompleted(let event): process(event: event)
        }
    }

    private func process(event: LoggerStoreEvent.NetworkTaskCompleted) {
        var transferSize = self.transferSize
        var duration = self.duration

        if let metrics = event.metrics {
            transferSize = transferSize.merging(metrics.transferSize)
        }
        if let metrics = event.metrics {
            duration.insert(duration: TimeInterval(metrics.taskInterval.duration), taskId: event.taskId)
        }

        DispatchQueue.main.async {
            self.transferSize = transferSize
            self.duration = duration
            self.didUpdate.send(())
        }
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
        public var values: [TimeInterval] = []

        /// Contains top slowest requests.
        public var topSlowestRequests: [UUID: TimeInterval] = [:]

        mutating func insert(duration: TimeInterval, taskId: UUID) {
            values.insert(duration, at: insertionIndex(for: duration))
            median = values[values.count / 2]
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
            topSlowestRequests[taskId] = duration
            if topSlowestRequests.count > 10 {
                let max = topSlowestRequests.max(by: { $0.value > $1.value })
                topSlowestRequests[max!.key] = nil
            }
        }

        private func insertionIndex(for duration: TimeInterval) -> Int {
            var lowerBound = 0
            var upperBound = values.count
            while lowerBound < upperBound {
                let mid = lowerBound + (upperBound - lowerBound) / 2
                if values[mid] == duration {
                    return mid
                } else if values[mid] < duration {
                    lowerBound = mid + 1
                } else {
                    upperBound = mid
                }
            }
            return lowerBound
        }
    }
}
