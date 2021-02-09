// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation

public struct LoggerSession {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }

    /// Returns current log session.
    public static var current = LoggerSession()

    /// Starts a new log session.
    public static func startSession() {
        LoggerSession.current = LoggerSession()
    }
}
