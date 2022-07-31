// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Combine
import SwiftUI

public final class LoggerStoreInsights: ObservableObject {
    private weak var logger: LoggerStore?
    private var cancellable: AnyCancellable?

    @Published private(set) var totalBytesSent: Int64 = 0
    @Published private(set) var bodyBytesSent: Int64 = 0
    @Published private(set) var headersBytesSent: Int64 = 0

    @Published private(set) var totalBytesReceived: Int64 = 0
    @Published private(set) var bodyBytesReceived: Int64 = 0
    @Published private(set) var headersBytesReceived: Int64 = 0

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
        
    }
}
