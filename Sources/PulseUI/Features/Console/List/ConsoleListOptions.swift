// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

struct ConsoleListOptions {
    var messageSortBy: MessageSortBy = .dateCreated
    var taskSortBy: TaskSortBy = .dateCreated
    var order: Ordering = .descending
    var messageGroupBy: MessageGroupBy = .noGrouping
    var taskGroupBy: TaskGroupBy = .noGrouping

    enum Ordering: String, CaseIterable {
        case descending = "Descending"
        case ascending = "Ascending"
    }

    enum MessageSortBy: String, CaseIterable {
        case dateCreated = "Date Created"

        var keyPath: String { "createdAt" }
    }

    enum TaskSortBy: String, CaseIterable {
        case dateCreated = "Date Created"
        case duration = "Duration"
        case requestSize = "Request Size"
        case responseSize = "Response Size"

        var keyPath: String {
            switch self {
            case .dateCreated: return "createdAt"
            case .duration: return "duration"
            case .requestSize: return "responseBodySize"
            case .responseSize: return "requestBodySize"
            }
        }
    }

    enum MessageGroupBy: String, CaseIterable {
        case noGrouping = "No Grouping"
        case label = "Label"
        case level = "Level"
        case file = "File"

        var keyPath: String? {
            switch self {
            case .noGrouping: return nil
            case .label: return "label"
            case .level: return "level"
            case .file: return "file"
            }
        }
    }

    enum TaskGroupBy: String, CaseIterable {
        case noGrouping = "No Grouping"
        case url = "URL"
        case host = "Host"
        case method = "Method"
        case taskType = "Task Type"
        case statusCode = "Status Code"
        case errorCode = "Error Code"

        var keyPath: String? {
            switch self {
            case .noGrouping: return nil
            case .url: return "url"
            case .host: return "host"
            case .method: return "method"
            case .taskType: return "taskType"
            case .statusCode: return "status"
            case .errorCode: return "errorCode"
            }
        }
    }
}
