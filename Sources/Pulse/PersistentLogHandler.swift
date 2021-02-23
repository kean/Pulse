// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import Logging

public typealias NetworkLogger = PulseCore.NetworkLogger
public typealias LoggerMessageStore = PulseCore.LoggerMessageStore
public typealias LoggerSession = PulseCore.LoggerSession
public typealias BlobStore = PulseCore.BlobStore
public typealias URLSessionProxyDelegate = PulseCore.URLSessionProxyDelegate

public extension NetworkLogger {
    /// - parameter logger: By default, create a Logger with "network" label and
    /// `logLevel` set `.trace`. Assumes that the `LoggingSystem.bootstrap` is used.
    /// - parameter blobs: By default, uses `BlobStore.default`. If you want to use
    /// a custom blob store, make sure to pass the same store to `ConsoleView` when
    /// instantiating it.
    convenience init(logger: Logger = NetworkLogger.makeDefaultLogger(),
                     blobStore: BlobStore = .default) {
        self.init(store: LoggerAdapter(logger: logger), blobStore: blobStore)
    }

    static func makeDefaultLogger() -> Logger {
        var logger = Logger(label: "network")
        logger.logLevel = .debug
        return logger
    }
}

public struct PersistentLogHandler {
    public var metadata = Logger.Metadata()
    public var logLevel = Logger.Level.info

    private let store: LoggerMessageStore

    private let label: String

    public init(label: String) {
        self.init(label: label, store: .default)
    }

    public init(label: String, store: LoggerMessageStore) {
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

// MARK: - Private (Adapters)

private struct LoggerAdapter: LoggerMessageStoring {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    // Ignores the label and uses the level set by Logger.
    func storeMessage(label: String, level: LoggerMessageStore.Level, message: String, metadata: [String : LoggerMessageStore.MetadataValue]?, file: String, function: String, line: UInt) {
        logger.log(level: .init(level), .init(stringLiteral: message), metadata: metadata.map(Logger.Metadata.init))
    }
}

// MARK: - Private (Logger.Level <-> LoggerMessageStore.Level)

private extension Logger.Level {
    init(_ level: LoggerMessageStore.Level) {
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

private extension LoggerMessageStore.Level {
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

// MARK: - Private (Logger.Metadata <-> LoggerMessageStore.Metadata)

private extension Logger.Metadata {
    init(_ metadata: LoggerMessageStore.Metadata) {
        self = metadata.mapValues(Logger.MetadataValue.init)
    }
}

private extension LoggerMessageStore.Metadata {
    init(_ metadata: Logger.Metadata) {
        self = metadata.compactMapValues(LoggerMessageStore.MetadataValue.init)
    }
}

private extension Logger.MetadataValue {
    init(_ value: LoggerMessageStore.MetadataValue) {
        switch value {
        case .string(let value): self = .string(value)
        case .stringConvertible(let value): self = .stringConvertible(value)
        }
    }
}

private extension LoggerMessageStore.MetadataValue {
    init?(_ value: Logger.MetadataValue) {
        switch value {
        case .string(let value): self = .string(value)
        case .stringConvertible(let value): self = .stringConvertible(value)
        case .dictionary(_): return nil // Unsupported
        case .array(_): return nil // Unsupported
        }
    }
}

