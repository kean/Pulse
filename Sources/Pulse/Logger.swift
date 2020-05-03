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

    public let container: NSPersistentContainer

    let backgroundContext: NSManagedObjectContext

    public convenience init(name: String) {
        let container = NSPersistentContainer(name: name, managedObjectModel: Logger.Store.model)
        container.loadPersistentStores { _, error in
            if let error = error {
                debugPrint("Failed to load persistent store with error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        self.init(container: container)
    }

    public init(container: NSPersistentContainer) {
        self.container = container
        self.backgroundContext = container.newBackgroundContext()
    }

    /// Logs the message in the console (if enabled) and saves it persistently.
    ///
    /// - parameter level: Log level, `.debug` by default.
    /// - parameter system: System, `.default` by default.
    /// - parameter category: Category, `.default` by default.
    /// - parameter message: The actual message to log.
    public func log(level: Level = .debug, system: System = .default, category: Category = .default, _ text: @autoclosure () -> String) {
        guard isEnabled else { return }

        let text = text()

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

        backgroundContext.perform {
            let message = LoggerMessage(context: self.backgroundContext)
            message.createdAt = Date()
            message.level = level.rawValue
            message.system = system.rawValue
            message.category = category.rawValue
            message.session = self.logSessionId.uuidString
            message.text = text

            try? self.backgroundContext.save()
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
