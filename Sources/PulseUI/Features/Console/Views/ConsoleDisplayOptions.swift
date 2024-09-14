// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Foundation

/// Configuration
public struct ConsoleDisplayOptions: Codable {
    // MARK: - Header

    public var headerFontSize: Int = defaultHeaderFooterFontSize

    /// The line limit for messages in the console. By default, `1`.
    public var headerLineLimit: Int = 1

#if os(macOS) || os(tvOS)
    /// Fields to display below the main text label.
    public var headerFields: [Field] = [.responseSize, .duration, .host]
#else
    /// Fields to display below the main text label.
    public var headerFields: [Field] = [.responseSize, .duration]
#endif

    // MARK: - Content

    /// If task description is available, show it instead of the `URL`.
    public var showTaskDescription = false

    /// Defines what components to display in the list. By default, shows
    /// only path.
    public var contentComponents: Set<ContentComponent> = [.path]

    public var contentFontSize: Int = defaultContentFontSize

    /// The line limit for messages in the console. By default, `3`.
    public var contentLineLimit: Int = 3

    // MARK: - Footer

    public var footerFontSize: Int = defaultHeaderFooterFontSize

    /// The line limit for messages in the console. By default, `1`.
    public var footerLineLimit: Int = 1

    // MARK: Helpers

    public enum ContentComponent: String, Identifiable, CaseIterable, Codable {
        case scheme, user, password, host, port, path, query, fragment

        public var id: ContentComponent { self }
    }

    public enum Field: Codable, Identifiable, CaseIterable {
        case method
        case requestSize
        case responseSize
        case responseContentType
        case duration
        case host
        case statusCode
        /// The type of the task, e.g. "Data" or "Download"
        case taskType
        /// The `taskDescription` value of `URLSessionTask`.
        case taskDescription

        public var id: Field { self }

        var title: String {
            switch self {
            case .method: "Method"
            case .requestSize: "Request Size"
            case .responseSize: "Response Size"
            case .responseContentType: "Response Content Type"
            case .duration: "Duration"
            case .host: "Host"
            case .statusCode: "Status Code"
            case .taskType: "Task Type"
            case .taskDescription: "Task Description"
            }
        }
    }

    public enum FontSize: CGFloat, Codable {
        case extraSmall = 0.8
        case small = 0.9
        case regular = 1.0
        case large = 1.1
        case extraLarge = 1.2
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
