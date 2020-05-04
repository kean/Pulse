// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

public final class Logger {
    /// Set `isEnabled` to `false` to disable all of the logging.
    public var isEnabled = true

    /// Set to `false` to disable printing into console.
    public var isConsoleEnabled = true

    /// An id of the current log sesion.
    public private(set) var logSessionId = UUID()

    /// Starts a new log session.
    public func startSession() {
        logSessionId = UUID()
    }

    /// A default logger.
    public static let `default` = Logger(name: "com.github.kean.logger")

    public let store: Store

    /// Logs expiration interval, 7 days by default.
    public var logsExpirationInterval: TimeInterval = 60 * 60 * 24 * 7

    /// Initializes logger with the given name.
    public convenience init(name: String) {
        self.init(store: Store(name: name))
    }

    public init(store: Store) {
        self.store = store

        scheduleSweep()
    }

    private func scheduleSweep() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(10)) { [weak self] in
            guard let self = self, self.isEnabled else { return }
            self.store.sweep(expirationInterval: self.logsExpirationInterval)
        }
    }

    /// Logs the message in the console (if enabled) and saves it persistently.
    ///
    /// - note: Logger automatically captures stack traces for .fatal logs.
    ///
    /// - parameter level: Log level, `.debug` by default.
    /// - parameter system: System, `.default` by default.
    /// - parameter category: Category, `.default` by default.
    /// - parameter message: The actual message to log.
    public func log(level: Level = .debug, system: System = .default, category: Category = .default, _ text: @autoclosure () -> String) {
        guard isEnabled else { return }

        var text = text()

        if level == .fatal {
            text += """
            \n
            Stack Trace
            ===========
            \(Thread.callStackSymbols)
            """
        }

        if isConsoleEnabled {
            let components = [
                system == .default ? nil : system.rawValue,
                category == .default ? nil : category.rawValue
            ]
            .compactMap { $0 }
            let prefix = components.isEmpty ? "" : "[\(components.joined(separator: ":"))]"

            NSLog("[\(level.rawValue)]\(prefix) \(text)")
            // For some reason, Swift Package Manager can't build a framework OSLog.
            // let type: OSLogType
            // switch level {
            // case .debug: type = .debug
            // case .error: type = .error
            // case .fatal: type = .fault
            // case .info: type = .info
            // }
            // os_log(type, "[%{PUBLIC}@:%{PUBLIC}@] %{PUBLIC}@", system.rawValue, category.rawValue, text)
        }

        let context = self.store.backgroundContext
        let sessionId = self.logSessionId.uuidString
        context.perform {
            let message = LoggerMessage(context: context)
            message.createdAt = Date()
            message.level = level.rawValue
            message.system = system.rawValue
            message.category = category.rawValue
            message.session = sessionId
            message.text = text

            try? context.save()
        }
    }
}

/// Logs the message in the console (if enabled) and saves it persistently.
///
/// - parameter level: Log level, `.debug` by default.
/// - parameter system: System, `.default` by default.
/// - parameter category: Category, `.default` by default.
/// - parameter message: The actual message to log.
public func log(level: Logger.Level = .debug, system: Logger.System = .default, category: Logger.Category = .default, _ text: @autoclosure () -> String) {
    guard Logger.default.isEnabled else { return }
    Logger.default.log(level: level, system: system, category: category, text())
}

public extension Logger {
    enum Level: String {
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

    struct System: Hashable, ExpressibleByStringLiteral {
        public let rawValue: String
        public init(stringLiteral value: String) { self.rawValue = value }
        public init(_ value: String) { self.rawValue = value }

        public static let `default` = System("default")
    }

    struct Category: Hashable, ExpressibleByStringLiteral {
        public let rawValue: String
        public init(stringLiteral value: String) { self.rawValue = value }
        public init(_ value: String) { self.rawValue = value }

        public static let `default` = Category("default")
    }
}
