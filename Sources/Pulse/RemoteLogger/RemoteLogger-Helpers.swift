// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network

// MARK: - Helpers (Descriptions)

@available(iOS 14.0, tvOS 14.0, *)
extension NWBrowser.State {
    var description: String {
        switch self {
        case .setup: return "NWBrowser.State.setup"
        case .ready: return "NWBrowser.State.ready"
        case .failed(let error): return "NWBrowser.State.failed(error: \(error.localizedDescription)"
        case .cancelled: return "NWBrowser.State.cancelled"
        case .waiting(let error): return "NWBrowser.State.waiting(error: \(error.localizedDescription)"
        @unknown default: return "NWBrowser.State.unknown"
        }
    }
}

@available(iOS 14.0, tvOS 14.0, *)
extension NWConnection.State {
    var description: String {
        switch self {
        case .setup: return "NWConnectionState.setup"
        case .ready: return "NWConnectionState.ready"
        case .failed(let error): return "NWConnectionState.failed(error: \(error.localizedDescription)"
        case .cancelled: return "NWConnectionState.cancelled"
        case .waiting(let error): return "NWConnectionState.waiting(error: \(error.localizedDescription)"
        case .preparing: return "MWBrowser.State.preparing"
        @unknown default: return "NWConnectionState.unknown"
        }
    }
}
