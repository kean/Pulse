// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine
import SwiftUI

/// Collects insights about the current session.
public final class LoggerStoreInsights: ObservableObject {
    private weak var logger: LoggerStore?
    private var cancellable: AnyCancellable?

    @Published private(set) public var transferSize = NetworkLoggerMetrics.TransferSize()

    public init(logger: LoggerStore) {
        cancellable = logger.events.receive(on: DispatchQueue.main).sink { [weak self] in
            self?.process(event: $0)
        }
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
        if let metrics = event.metrics {
            transferSize = transferSize.merging(metrics.transferSize)
        }
    }

    // TODO: Add a way to reset

    // - Redirects (Bad) + how much time can save total
    // - Slow response (Warning)
    // - Errors
}
