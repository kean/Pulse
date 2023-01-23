// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

extension LoggerStore {
    @available(*, deprecated, message: "Session are now managed on a database level and has associated metadata, e.g. creation date. See LoggerSessionEntity for more info.")
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
