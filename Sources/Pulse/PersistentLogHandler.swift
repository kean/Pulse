// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import Foundation
import Logging

public struct PersistentLogHandler {
    public var metadata = Logger.Metadata()
    public var logLevel = Logger.Level.info

    /// An id of the current log sesion.
    public private(set) var logSessionId = UUID()

    private let store: LoggerMessageStore
    private let makeCurrentDate: () -> Date

    private let label: String

    public init(label: String, store: LoggerMessageStore = .default) {
        self.label = label
        self.store = store
        self.makeCurrentDate = Date.init
    }

    init(label: String, store: LoggerMessageStore, makeCurrentDate: @escaping () -> Date) {
        self.label = label
        self.store = store
        self.makeCurrentDate = makeCurrentDate
    }
}

extension PersistentLogHandler: LogHandler {
    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            metadata[key]
        } set(newValue) {
            metadata[key] = newValue
        }
    }

    /// Starts a new log session.
    public mutating func startSession() {
        logSessionId = UUID()
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let context = store.backgroundContext
        let date = makeCurrentDate()
        let session = logSessionId.uuidString

        context.perform {
            let persistedMessage = LoggerMessage(context: context)
            persistedMessage.createdAt = date
            persistedMessage.level = level.rawValue
            #warning("Question: Use the Logger's label as system?")
            persistedMessage.system = "default"
            #warning("Question: What would be the equivalent in swift-log?")
            persistedMessage.category = "default"
            persistedMessage.session = session
            persistedMessage.text = String(describing: message)
            try? context.save()
        }
    }
}
