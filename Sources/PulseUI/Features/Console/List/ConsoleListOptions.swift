// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

struct ConsoleListOptions: Equatable {
    var messageSortBy: MessageSortBy = .dateCreated
    var taskSortBy: TaskSortBy = .dateCreated
    var order: Ordering = .descending

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
}
