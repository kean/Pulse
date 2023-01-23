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
        case dateCreated = "Date"
        case level = "Level"

        var key: String {
            switch self {
            case .dateCreated: return "createdAt"
            case .level: return "level"
            }
        }
    }

    enum TaskSortBy: String, CaseIterable {
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

    enum MessageGroupBy: String, CaseIterable, ConsoleListGroupBy {
        case noGrouping = "No Grouping"
        case label = "Label"
        case level = "Level"
        case file = "File"

        var key: String? {
            switch self {
            case .noGrouping: return nil
            case .label: return "label.name"
            case .level: return "level"
            case .file: return "file"
            }
        }

        var isAscending: Bool {
            switch self {
            case .noGrouping, .label, .file: return true
            case .level: return false
            }
        }
    }

    enum TaskGroupBy: String, ConsoleListGroupBy {
        case noGrouping = "No Grouping"
        case url = "URL"
        case host = "Host"
        case method = "Method"
        case taskType = "Task Type"
        case statusCode = "Status Code"
        case errorCode = "Error Code"
        case requestState = "State"

        var key: String? {
            switch self {
            case .noGrouping: return nil
            case .url: return "url"
            case .host: return "host.value"
            case .method: return "httpMethod"
            case .taskType: return "taskType"
            case .statusCode: return "statusCode"
            case .errorCode: return "errorCode"
            case .requestState: return "requestState"
            }
        }

        var isAscending: Bool {
            self != .errorCode
        }
    }
}

protocol ConsoleListGroupBy {
    var key: String? { get }
    var isAscending: Bool { get }
}

