// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

/// Allows you to control Pulse appearance and other settings programmatically.
public final class UserSettings: ObservableObject {
    public static let shared = UserSettings()

    /// The console default mode.
    @AppStorage("com.github.kean.pulse.console.mode")
    public var mode: ConsoleMode = .network

    /// The line limit for messages in the console. By default, `3`.
    @AppStorage("com.github.kean.pulse.consoleCellLineLimit")
    public var lineLimit: Int = 3

    /// Enables link detection in the response viewier. By default, `false`.
    @AppStorage("com.github.kean.pulse.linkDetection")
    public var isLinkDetectionEnabled = false

    /// The default sharing output type. By default, ``ShareStoreOutput/store``.
    @AppStorage("com.github.kean.pulse.sharingOutput")
    public var sharingOutput: ShareStoreOutput = .store

    /// HTTP headers to display in a Console. By default, empty.
    public var displayHeaders: [String] {
        get { decode(rawDisplayHeaders) ?? [] }
        set { rawDisplayHeaders = encode(newValue) ?? "[]" }
    }

    @AppStorage("com.github.kean.pulse.display.headers")
    var rawDisplayHeaders: String = "[]"

    /// If `true`, the network inspector will show the current request by default.
    /// If `false`, show the original request.
    @AppStorage("com.github.kean.pulse.showCurrentRequest")
    public var isShowingCurrentRequest = true

    /// The allowed sharing options.
    public var allowedShareStoreOutputs: [ShareStoreOutput] {
        get { decode(rawAllowedShareStoreOutputs) ?? [] }
        set { rawAllowedShareStoreOutputs = encode(newValue) ?? "[]" }
    }

    @AppStorage("com.github.kean.pulse.allowedShareStoreOutputs")
    var rawAllowedShareStoreOutputs: String = "[]"

    /// If enabled, the console stops showing the remote logging option.
    @AppStorage("com.github.kean.pulse.isRemoteLoggingAllowed")
    public var isRemoteLoggingHidden = false

    /// Task cell display options.
    public var displayOptions: DisplayOptions {
        get {
            if let options = cachedDisplayOptions {
                return options
            }
            let options = decode(rawDisplayOptions) ?? DisplayOptions()
            cachedDisplayOptions = options
            return options
        }
        set {
            cachedDisplayOptions = newValue
            rawDisplayOptions = encode(newValue) ?? "{}"
        }
    }

    var cachedDisplayOptions: DisplayOptions?

    @AppStorage("com.github.kean.pulse.DisplayOptions")
    var rawDisplayOptions: String = "{}"

    /// Configuration
    public struct DisplayOptions: Codable {
        // MARK: - Header

        /// By default, `true`.
        public var isShowingDetails = true

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

typealias DisplayOptions = UserSettings.DisplayOptions

private func decode<T: Decodable>(_ string: String) -> T? {
    let data = string.data(using: .utf8) ?? Data()
    return (try? JSONDecoder().decode(T.self, from: data))
}

private func encode<T: Encodable>(_ value: T) -> String? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
}
