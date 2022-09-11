// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if !os(macOS) && !targetEnvironment(macCatalyst) && swift(>=5.7)
import Foundation
#else
@preconcurrency import Foundation
#endif

extension LoggerStore {
    public struct Session: Sendable {
        public let id: UUID

        public init(id: UUID = UUID()) {
            self.id = id
        }

        /// Returns current log session.
        public static var current = Session()

        /// Starts a new log session.
        public static func startSession() {
            LoggerStore.Session.current = Session()
        }
    }
}
