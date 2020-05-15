// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import Foundation
import Logging

public struct PersistentLogHandler2 {
    public var metadata = Logger.Metadata()
    public var logLevel = Logger.Level.info

    /// An id of the current log sesion.
    public static private(set) var logSessionId = UUID()

    private let store: LoggerMessageStore2
    private let makeCurrentDate: () -> Date

    private let label: String

    public init(label: String) {
        self.init(label: label, store: .default)
    }

    public init(label: String, store: LoggerMessageStore2) {
        self.label = label
        self.store = store
        self.makeCurrentDate = Date.init
    }

    init(label: String, store: LoggerMessageStore2, makeCurrentDate: @escaping () -> Date) {
        self.label = label
        self.store = store
        self.makeCurrentDate = makeCurrentDate
    }
}

extension PersistentLogHandler2: LogHandler {
    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get {
            metadata[key]
        } set(newValue) {
            metadata[key] = newValue
        }
    }

    /// Starts a new log session.
    @discardableResult
    public static func startSession() -> UUID {
        logSessionId = UUID()
        return logSessionId
    }

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let date = makeCurrentDate()
        let label = self.label

        let metadata = metadata?.unpack()
            .map { MetadataItem(key: $0, value: $1) }
            ?? []

        #warning("TODO: create temporary ID here")
        let item = MessageItem(
            id: Int.max,
            createdAt: date,
            level: level.rawValue,
            label: label,
            session: Self.logSessionId.uuidString,
            text: String(describing: message),
            metadata: metadata,
            file: file,
            function: function,
            line: Int32(line)
        )
        
        self.store.store(message: item)
    }
}

private extension Logger.Metadata {
    func unpack() -> [(String, String)] {
        var entries = [(String, String)]()
        for (key, value) in self {
            switch value {
            case let .string(string):
                entries.append((key, string))
            case let .stringConvertible(string):
                entries.append((key, string.description))
            default:
                break // Skip other types
            }
        }
        return entries
    }
}
