// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine

/// Collects insights about the current session.
public final class NetworkLoggerInsights {
    private var cancellables: [AnyCancellable] = []

    private(set) public var transferSize = NetworkLoggerMetrics.TransferSizeInfo()
    private(set) public var duration = RequestsDurationInfo()
    private(set) public var redirects = RedirectsInfo()

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
        guard let metrics = event.metrics else { return }

        var transferSize = self.transferSize
        var duration = self.duration
        var redirects = self.redirects

        transferSize = transferSize.merging(metrics.transferSize)
        duration.insert(duration: TimeInterval(metrics.taskInterval.duration), taskId: event.taskId)
        if metrics.redirectCount > 0 {
            redirects.count += metrics.redirectCount
            redirects.taskIds.append(event.taskId)
            redirects.timeLost += metrics.transactions
                .filter({ $0.response?.statusCode == 302 })
                .map { $0.duration ?? 0 }
                .reduce(0, +)
        }

        DispatchQueue.main.async {
            self.transferSize = transferSize
            self.duration = duration
            self.redirects = redirects
            self.didUpdate.send(())
        }
    }

    // TODO: Add a way to reset

    // - Redirects (Bad) + how much time can save total
    // - Slow response (Warning)
    // - Errors

    public struct RequestsDurationInfo {
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

    public struct RedirectsInfo {
        public var count: Int = 0
        public var timeLost: TimeInterval = 0
        public var taskIds: [UUID] = []

        public init() {}
    }
}
