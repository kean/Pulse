// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

enum ConsoleViewDelegate {
    static func getTitle(for task: NetworkTaskEntity) -> String? {
        if let taskDescription = task.taskDescription, !taskDescription.isEmpty {
            return taskDescription
        }
        return task.url
    }

    static func getShortTitle(for task: NetworkTaskEntity) -> String {
        guard let title = getTitle(for: task) else {
            return ""
        }
        return URL(string: title)?.lastPathComponent ?? title
    }
}
