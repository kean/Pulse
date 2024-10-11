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
        public var fontSize: Int

        /// The line limit for messages in the console. By default, `1`.
        public var lineLimit: Int

        /// Additinoal fields to display below the in the header.
        public var fields: [TaskField]

        public init(fontSize: Int? = nil, lineLimit: Int = 1, fields: [TaskField]? = nil) {
            self.fontSize = fontSize ?? ConsoleListDisplaySettings.defaultHeaderFooterFontSize
            self.lineLimit = lineLimit
            if let fields {
                self.fields = fields
            } else {
#if os(macOS) || os(tvOS)
                self.fields = [.responseSize, .duration, .host]
#else
                self.fields = [.responseSize, .duration]
#endif
            }
        }
    }

    /// Specifies how the main content of the is displaying, including the
    /// method, URL, or task description.
    public struct ContentSettings: Hashable, Codable {

        /// If task description is available, show it instead of the `URL`.
        public var showTaskDescription: Bool

        /// Show HTTP method when available.
        public var showMethod: Bool

        /// Defines what components to display in the list. By default, shows
        /// only path.
        public var components: Set<URLComponent>

        /// The default value is different based on the platform but typically
        /// matches the "body" font size.
        public var fontSize: Int

        /// The line limit for messages in the console. By default, `3`.
        public var lineLimit: Int

        /// If enabled, use monospaced font to display the content.
        public var isMonospaced = false

        public init(
            showTaskDescription: Bool = false,
            showMethod: Bool = true,
            components: Set<URLComponent> = [.path],
            fontSize: Int? = nil,
            lineLimit: Int = 3
        ) {
            self.showTaskDescription = showTaskDescription
            self.showMethod = showMethod
            self.components = components
            self.fontSize = fontSize ?? ConsoleListDisplaySettings.defaultContentFontSize
            self.lineLimit = lineLimit
        }
    }

    public struct FooterSettings: Sendable, Hashable, Codable {
        /// By default, matches the "footnote" style.
        public var fontSize: Int

        /// The line limit for messages in the console. By default, `1`.
        public var lineLimit: Int

        /// Fields to display horizontally below the main text label with a separator.
        public var fields: [TaskField]

        /// Additional fields to display below the main list.
        public var additionalFields: [TaskField] = []

        /// If enabled, use monospaced font to display the content.
        public var isMonospaced = false

        public init(fontSize: Int? = nil, lineLimit: Int = 1) {
            self.fontSize = fontSize ?? ConsoleListDisplaySettings.defaultHeaderFooterFontSize
            self.lineLimit = lineLimit
            self.fields = [.host]
        }
    }

    public enum URLComponent: String, CaseIterable, Codable {
        case scheme, user, password, host, port, path, query, fragment
    }

    public enum TaskField: Sendable, Codable, Hashable {
        case method
        case requestSize
        case responseSize
        case responseContentType
        case duration
        case host
        case statusCode
        case taskType
        case taskDescription
        case requestHeaderField(String)
        case responseHeaderField(String)
    }

    public init() {}
}

extension ConsoleListDisplaySettings {
#if os(watchOS)
    package static let defaultContentFontSize = 16
    package static let defaultHeaderFooterFontSize = 14
#elseif os(macOS)
    package static let defaultContentFontSize = 13
    package static let defaultHeaderFooterFontSize = 11
#elseif os(iOS) || os(visionOS)
    package static let defaultContentFontSize = 16
    package static let defaultHeaderFooterFontSize = 13
#elseif os(tvOS)
    package static let defaultContentFontSize = 27
    package static let defaultHeaderFooterFontSize = 21
#endif
}
