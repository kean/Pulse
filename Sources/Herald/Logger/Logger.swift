// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation

import os

public final class Logger {
    @objc public enum Level: Int16 {
        /// Verbose, fine-grained events.
        case debug
        /// Highlight the progress of the application at coarse-grained level.
        case info
        /// Errors which still allow the application to continue.
        case error
        /// Sever errors which prevent that prevent either parts of the application
        /// or the entire application from functioning.
        case fatal
    }

    public struct System: Hashable, ExpressibleByStringLiteral {
        public let rawValue: String
        public init(stringLiteral value: String) { self.rawValue = value }
        public init(_ value: String) { self.rawValue = value }

        public static let `default` = System("default")
    }

    public struct Category: Hashable, ExpressibleByStringLiteral {
        public let rawValue: String
        public init(stringLiteral value: String) { self.rawValue = value }
        public init(_ value: String) { self.rawValue = value }

        public static let `default` = Category("default")
    }

    public struct Message {
        public let created: Date
        public let level: Level
        public let system: System
        public let category: Category
        public let session: UUID
        public let text: String

        public init(created: Date, level: Level, system: System, category: Category, session: UUID, text: String) {
            self.created = created
            self.level = level
            self.system = system
            self.category = category
            self.session = session
            self.text = text
        }
    }

    /// Set `isEnabled` to `false` to disable all of the logging.
    public var isEnabled = true

    /// An id of the current log sesion.
    public private(set) var logSessionId = UUID()

    /// Starts a new log session.
    public func startNewLogSession() {
        logSessionId = UUID()
    }

    /// A default logger.
    public static let `default` = Logger()

    /// - parameter level: Log level, `.debug` by default.
    /// - parameter system: System, `.default` by default.
    /// - parameter category: Category, `.default` by default.
    /// - parameter message: The actual message to log.
    public func log(level: Level = .debug, system: System = .default, category: Category = .default, _ text: @autoclosure () -> String) {
        guard isEnabled else { return }

        let message = Message(
            created: Date(),
            level: level,
            system: system,
            category: category,
            session: logSessionId,
            text: text()
        )

        #warning("TODO: implement logging + saving logs, should I use os_log for this?")
    }
}
