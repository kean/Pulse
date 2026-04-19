// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

package struct ConsoleListOptions: Equatable {
    package var messageSortBy: MessageSortBy = .dateCreated
    package var taskSortBy: TaskSortBy = .dateCreated
#if os(macOS)
    package var order: Ordering = .ascending
#else
    package var order: Ordering = .descending
#endif

    package var messageGroupBy: MessageGroupBy = .noGrouping
    package var taskGroupBy: TaskGroupBy = .noGrouping

    package init() {}

    package enum Ordering: String, CaseIterable {
        case descending = "Descending"
        case ascending = "Ascending"
    }

    package enum MessageSortBy: String, CaseIterable {
        case dateCreated = "Date"
        case level = "Level"

        package var key: String {
            switch self {
            case .dateCreated: return "createdAt"
            case .level: return "level"
            }
        }

        package var pillTitle: String { rawValue }
    }

    package enum TaskSortBy: String, CaseIterable {
        case dateCreated = "Date"
        case duration = "Duration"
        case requestSize = "Request Size"
        case responseSize = "Response Size"

        package var key: String {
            switch self {
            case .dateCreated: return "createdAt"
            case .duration: return "duration"
            case .requestSize: return "requestBodySize"
            case .responseSize: return "responseBodySize"
            }
        }

        package var pillTitle: String {
            switch self {
            case .dateCreated: return "Date"
            case .duration: return "Duration"
            case .requestSize: return "Size"
            case .responseSize: return "Size"
            }
        }
    }

    package enum MessageGroupBy: String, CaseIterable, ConsoleListGroupBy {
        case noGrouping = "No Grouping"
        case label = "Label"
        case level = "Level"
        case file = "File"
        case session = "Session"

        package var key: String? {
            switch self {
            case .noGrouping: return nil
            case .label: return "label"
            case .level: return "level"
            case .file: return "file"
            case .session: return "session"
            }
        }

        package var isAscending: Bool {
            switch self {
            case .noGrouping, .label, .file: return true
            case .level, .session: return false
            }
        }
    }

    package enum TaskGroupBy: String, CaseIterable, ConsoleListGroupBy {
        case noGrouping = "No Grouping"
        case url = "URL"
        case host = "Host"
        case method = "Method"
        case taskType = "Task Type"
        case statusCode = "Status Code"
        case errorCode = "Error Code"
        case requestState = "State"
        case responseContentType = "Content Type"
        case session = "Session"

        package var key: String? {
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

        package var isAscending: Bool {
            self != .errorCode && self != .session
        }
    }
}

package protocol ConsoleListGroupBy {
    var key: String? { get }
    var isAscending: Bool { get }
}
