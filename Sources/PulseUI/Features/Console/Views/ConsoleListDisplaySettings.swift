// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

/// Defines the configuration options for displaying network tasks in the console.
public struct ConsoleListDisplaySettings: Hashable, Codable {
    /// Specifies what is displayed in the network task cell header.
    public var header = HeaderSettings()

    /// Specifies how the main content of the is displaying, including the
    /// method, URL, or task description.
    public var content = ContentSettings()

    /// Specifies what is displayed in the footer of the task cells.
    public var footer = FooterSettings()

    /// Specifies what is displayed in the network task cell header.
    public struct HeaderSettings: Hashable, Codable {
        public var fontSize: Int = defaultHeaderFooterFontSize

        /// The line limit for messages in the console. By default, `1`.
        public var lineLimit: Int = 1

    #if os(macOS) || os(tvOS)
        /// Fields to display below the main text label.
        public var fields: [TaskField] = [.responseSize, .duration, .host]
    #else
        /// Fields to display below the main text label.
        public var fields: [TaskField] = [.responseSize, .duration]
    #endif
    }

    /// Specifies how the main content of the is displaying, including the
    /// method, URL, or task description.
    public struct ContentSettings: Hashable, Codable {

        /// If task description is available, show it instead of the `URL`.
        public var showTaskDescription = false

        /// Defines what components to display in the list. By default, shows
        /// only path.
        public var components: Set<URLComponent> = [.path]

        /// The default value is different based on the platform but typically
        /// matches the "body" font size.
        public var fontSize: Int = defaultContentFontSize

        /// The line limit for messages in the console. By default, `3`.
        public var lineLimit: Int = 3
    }

    public struct FooterSettings: Sendable, Hashable, Codable {
        /// By default, matches the "footnote" style.
        public var fontSize: Int = defaultHeaderFooterFontSize

        /// The line limit for messages in the console. By default, `1`.
        public var lineLimit: Int = 1
    }

    public enum URLComponent: String, Identifiable, CaseIterable, Codable {
        case scheme, user, password, host, port, path, query, fragment

        public var id: URLComponent { self }
    }

    public enum TaskField: Sendable, Codable, Hashable, Identifiable {
        case method
        case requestSize
        case responseSize
        case responseContentType
        case duration
        case host
        case statusCode
        case taskType
        case taskDescription
        case requestHeaderField(key: String)
        case responseHeaderField(key: String)

        public var id: TaskField { self }
    }

    public init() {}
}

#if os(watchOS)
let defaultContentFontSize = 17
let defaultHeaderFooterFontSize = 14
#elseif os(macOS)
let defaultContentFontSize = 13
let defaultHeaderFooterFontSize = 11
#elseif os(iOS) || os(visionOS)
let defaultContentFontSize = 17
let defaultHeaderFooterFontSize = 13
#elseif os(tvOS)
let defaultContentFontSize = 27
let defaultHeaderFooterFontSize = 21
#endif
