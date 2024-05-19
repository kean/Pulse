// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

/// Allows you to customize the console behavior.
public protocol ConsoleViewDelegate {
    /// Returns a title for the given task.
    func getTitle(for task: NetworkTaskEntity) -> String?
}

extension ConsoleViewDelegate {
    func getTitle(for task: NetworkTaskEntity) -> String? {
        if let taskDescription = task.taskDescription, !taskDescription.isEmpty {
            return taskDescription
        }
        return task.url
    }
}

struct DefaultConsoleViewDelegate: ConsoleViewDelegate {}
