// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

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
