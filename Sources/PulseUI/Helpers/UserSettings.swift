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
    public var consoleTaskDisplayOptions: ConsoleTaskDisplayOptions {
        get {
            if let options = cachedConsoleTaskDisplayOptions {
                return options
            }
            let options = decode(rawConsoleTaskDisplayOptions) ?? ConsoleTaskDisplayOptions()
            cachedConsoleTaskDisplayOptions = options
            return options
        }
        set {
            cachedConsoleTaskDisplayOptions = newValue
            rawConsoleTaskDisplayOptions = encode(newValue) ?? "{}"
        }
    }

    var cachedConsoleTaskDisplayOptions: ConsoleTaskDisplayOptions?

    @AppStorage("com.github.kean.pulse.consoleTaskDisplayOptions")
    var rawConsoleTaskDisplayOptions: String = "{}"
}

public struct ConsoleTaskDisplayOptions: Codable {
    /// The line limit for messages in the console. By default, `3`.
    public var lineLimit: Int = 3

    /// Fields to display below the main text label.
    public var details: [Field]

    public enum Field: Codable, Identifiable, CaseIterable {
        case method
        case requestSize
        case responseSize
        case duration

        public var id: Field { self }

        var title: String {
            switch self {
            case .method: "Method"
            case .requestSize: "Request Size"
            case .responseSize: "Response Size"
            case .duration: "Duration"
            }
        }
    }

    public init(
        details: [Field] = [.method, .requestSize, .responseSize, .duration]
    ) {
        self.details = details
    }
}

private func decode<T: Decodable>(_ string: String) -> T? {
    let data = string.data(using: .utf8) ?? Data()
    return (try? JSONDecoder().decode(T.self, from: data))
}

private func encode<T: Encodable>(_ value: T) -> String? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
}
