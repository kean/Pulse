// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

public final class Logger {
    public enum Level: String {
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

    /// Set `isEnabled` to `false` to disable all of the logging.
    public var isEnabled = true

    /// An id of the current log sesion.
    public private(set) var logSessionId = UUID()

    /// Starts a new log session.
    public func startNewLogSession() {
        logSessionId = UUID()
    }

    /// A default logger.
    public static let `default` = Logger(name: "com.github.kean.logger")

    public let container: NSPersistentContainer

    let backgroundContext: NSManagedObjectContext

    public convenience init(name: String) {
        let container = NSPersistentContainer(name: name, managedObjectModel: LoggerStorage.coreDataModel)
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        self.init(container: container)
    }

    public init(container: NSPersistentContainer) {
        self.container = container

        container.loadPersistentStores { _, error in
            if let error = error {
                debugPrint("Failed to load persistent store with error: \(error)")
            }
        }

        self.backgroundContext = container.newBackgroundContext()
    }

    /// - parameter level: Log level, `.debug` by default.
    /// - parameter system: System, `.default` by default.
    /// - parameter category: Category, `.default` by default.
    /// - parameter message: The actual message to log.
    public func log(level: Level = .debug, system: System = .default, category: Category = .default, _ text: @autoclosure () -> String) {
        guard isEnabled else { return }

        #warning("TODO: implement logging + saving logs, should I use os_log for this?")
    }
}
