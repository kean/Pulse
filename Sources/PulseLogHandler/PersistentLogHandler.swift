// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import Logging

public typealias NetworkLogger = Pulse.NetworkLogger
public typealias LoggerStore = Pulse.LoggerStore
public typealias URLSessionProxyDelegate = Pulse.URLSessionProxyDelegate

/// Allows ``LoggerStore`` to be used with with [SwiftLog](https://github.com/apple/swift-log).
///
/// ```swift
/// import PulseLogHandler
/// import Logging
///
/// LoggingSystem.bootstrap(PersistentLogHandler.init)
/// ```
///
/// If used this way, you never need to interact with the store directly. To log
/// messages, you'll interact only with the SwiftLog APIs.
///
/// ```swift
/// let logger = Logger(label: "com.yourcompany.yourapp")
/// logger.info("This message will be stored persistently")
/// ```
public struct PersistentLogHandler {
    public var metadata = Logger.Metadata()
    public var logLevel = Logger.Level.info

    private let store: LoggerStore

    private let label: String

    public init(label: String) {
        self.init(label: label, store: .shared)
    }

    public init(label: String, store: LoggerStore) {
        self.label = label
        self.store = store
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

    public func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        var mergedMetadata = self.metadata
        for (key, value) in metadata ?? [:] {
            mergedMetadata[key] = value // Override keys if necessary
        }
        store.storeMessage(label: label, level: .init(level), message: message.description, metadata: .init(mergedMetadata), file: file, function: function, line: line)
    }
}

// MARK: - Private (Logger.Level <-> LoggerStore.Level)

private extension LoggerStore.Level {
    init(_ level: Logger.Level) {
        switch level {
        case .trace: self = .trace
        case .debug: self = .debug
        case .info: self = .info
        case .notice: self = .notice
        case .warning: self = .warning
        case .error: self = .error
        case .critical: self = .critical
        }
    }
}

// MARK: - Private (Logger.Metadata <-> LoggerStore.Metadata)

private extension LoggerStore.Metadata {
    init(_ metadata: Logger.Metadata) {
        self = metadata.compactMapValues(LoggerStore.MetadataValue.init)
    }
}

private extension LoggerStore.MetadataValue {
    init?(_ value: Logger.MetadataValue) {
        switch value {
        case .string(let value): self = .string(value)
        case .stringConvertible(let value): self = .stringConvertible(value)
        case .dictionary: return nil // Unsupported
        case .array: return nil // Unsupported
        }
    }
}
