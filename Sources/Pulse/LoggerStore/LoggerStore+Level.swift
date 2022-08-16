// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

extension LoggerStore {
    @frozen public enum MetadataValue {
        case string(String)
        case stringConvertible(CustomStringConvertible)
    }

    public typealias Metadata = [String: MetadataValue]

    // Compatible with SwiftLog.Logger.Level
    @frozen public enum Level: Int16, CaseIterable, Codable, Hashable, Sendable {
        case trace = 1
        case debug
        case info
        case notice
        case warning
        case error
        case critical

        public var name: String {
            switch self {
            case .trace: return "trace"
            case .debug: return "debug"
            case .info: return "info"
            case .notice: return "notice"
            case .warning: return "warning"
            case .error: return "error"
            case .critical: return "critical"
            }
        }
    }
}

extension Dictionary where Key == String, Value == LoggerStore.MetadataValue {
    func unpack() -> [String: String] {
        var entries = [String: String]()
        for (key, value) in self {
            switch value {
            case let .string(string): entries[key] = string
            case let .stringConvertible(string): entries[key] = string.description
            }
        }
        return entries
    }
}
