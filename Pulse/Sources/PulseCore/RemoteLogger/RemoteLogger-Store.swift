// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import Network
import Combine
import SwiftUI

// These methods are not designed to be used publicly.
@available(iOS 14.0, tvOS 14.0, watchOS 7.0, *)
extension RemoteLogger {
    public static func store(_ message: LoggerStore.Message, into store: LoggerStore) {
        store.storeMessage(message)
    }
    
    public static func store(_ message: LoggerStore.NetworkMessage, into store: LoggerStore) {
        store.storeRequest(message)
    }
}
