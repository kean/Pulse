// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

public struct ConsoleListOptions: Equatable {
    public var messageSortBy: MessageSortBy = .dateCreated
    public var taskSortBy: TaskSortBy = .dateCreated
#if os(macOS)
    public var order: Ordering = .ascending
#else
    public var order: Ordering = .descending
#endif

    public var messageGroupBy: MessageGroupBy = .noGrouping
    public var taskGroupBy: TaskGroupBy = .noGrouping

    public enum Ordering: String, CaseIterable {
        case descending = "Descending"
        case ascending = "Ascending"
    }

    public enum MessageSortBy: String, CaseIterable {
        case dateCreated = "Date"
        case level = "Level"

        var key: String {
            switch self {
            case .dateCreated: return "createdAt"
            case .level: return "level"
            }
        }
    }

    public enum TaskSortBy: String, CaseIterable {
        case dateCreated = "Date"
        case duration = "Duration"
        case requestSize = "Request Size"
        case responseSize = "Response Size"

        var key: String {
            switch self {
            case .dateCreated: return "createdAt"
            case .duration: return "duration"
            case .requestSize: return "requestBodySize"
            case .responseSize: return "responseBodySize"
            }
        }
    }

    public enum MessageGroupBy: String, CaseIterable, ConsoleListGroupBy {
        case noGrouping = "No Grouping"
        case label = "Label"
        case level = "Level"
        case file = "File"
        case session = "Session"

        var key: String? {
            switch self {
            case .noGrouping: return nil
            case .label: return "label"
            case .level: return "level"
            case .file: return "file"
            case .session: return "session"
            }
        }

        var isAscending: Bool {
            switch self {
            case .noGrouping, .label, .file: return true
            case .level, .session: return false
            }
        }
    }

    public enum TaskGroupBy: ConsoleListGroupBy {
        case noGrouping
        case url
        case host
        case method
        case taskType
        case statusCode
        case errorCode
        case requestState
        case responseContentType
        case session

        var key: String? {
            switch self {
            case .noGrouping: return nil
            case .url: return "url"
            case .host: return "host"
            case .method: return "httpMethod"
            case .taskType: return "taskType"
            case .statusCode: return "statusCode"
            case .errorCode: return "errorCode"
            case .requestState: return "requestState"
            case .responseContentType: return "responseContentType"
            case .session: return "session"
            }
        }

        var isAscending: Bool {
            self != .errorCode && self != .session
        }
    }

    public init() {}
}

protocol ConsoleListGroupBy {
    var key: String? { get }
    var isAscending: Bool { get }
}
