// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import SwiftUI

/// A global set of configuration for the console.
/// These values can be changed to customize default behavior.
public enum ConsoleConfiguration {
    /// Global message builder for rows
    public static var messageBuilder: TaskMessageBuilder = URLTaskMessageBuilder()
}

/// A message builder is used to build information about the task to be displayed in
/// the console list
public protocol TaskMessageBuilder {
    /// Build the view to be displayed in the console list
    func buildView(task: NetworkTaskEntity) -> AnyView
}

/// A simple task message builder that displays the URL only
public struct URLTaskMessageBuilder: TaskMessageBuilder {
    public init() {}

    public func buildView(task: NetworkTaskEntity) -> AnyView {
        AnyView(
            Text(task.url ?? "–")
                .font(ConsoleConstants.fontBody)
                .foregroundColor(.primary)
                .lineLimit(ConsoleSettings.shared.lineLimit)
        )
    }
}
