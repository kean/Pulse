// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

/// Allows you to control Pulse appearance and other settings programmatically.
public final class UserSettings: ObservableObject {
    public static let shared = UserSettings()

    /// The console default mode.
    @AppStorage("com_github_kean_pulse_console_mode")
    public var mode: ConsoleMode = .network

    /// The line limit for messages in the console. By default, `3`.
    @AppStorage("com_github_kean_pulse_console_cell_line_limit")
    public var lineLimit: Int = 3

    /// Enables link detection in the response viewier. By default, `false`.
    @AppStorage("com_github_kean_pulse_link_detection")
    public var isLinkDetectionEnabled = false

    /// The default sharing output type. By default, ``ShareStoreOutput/store``.
    @AppStorage("com_github_kean_pulse_sharing_output")
    public var sharingOutput: ShareStoreOutput = .store

    // Deprecated in Pulse 5.1.
    @available(*, deprecated, message: "Replaced with listDisplayOptions.header.fields and listDisplayOptions.footer.fields")
    public var displayHeaders: [String] {
        get { [] }
        set { }
    }

    /// If `true`, the network inspector will show the current request by default.
    /// If `false`, show the original request.
    @AppStorage("com_github_kean_pulse_show_current_request")
    public var isShowingCurrentRequest = true

    /// The allowed sharing options.
    public var allowedShareStoreOutputs: [ShareStoreOutput] {
        get { decode(rawAllowedShareStoreOutputs) ?? [] }
        set { rawAllowedShareStoreOutputs = encode(newValue) ?? "[]" }
    }

    @AppStorage("com_github_kean_pulse_allowed_share_store_outputs")
    var rawAllowedShareStoreOutputs: String = "[]"

    /// If enabled, the console stops showing the remote logging option.
    @AppStorage("com_github_kean_pulse_is_remote_logging_allowed")
    public var isRemoteLoggingHidden = false

    /// Task cell display options.
    public var listDisplayOptions: ConsoleListDisplaySettings {
        get {
            if let options = cachedDisplayOptions {
                return options
            }
            let options = decode(rawDisplayOptions) ?? ConsoleListDisplaySettings()
            cachedDisplayOptions = options
            return options
        }
        set {
            cachedDisplayOptions = newValue
            rawDisplayOptions = encode(newValue) ?? "{}"
        }
    }

    var cachedDisplayOptions: ConsoleListDisplaySettings?

    @AppStorage("com_github_kean_pulse_display_options")
    var rawDisplayOptions: String = "{}"
}

private func decode<T: Decodable>(_ string: String) -> T? {
    let data = string.data(using: .utf8) ?? Data()
    return (try? JSONDecoder().decode(T.self, from: data))
}

private func encode<T: Encodable>(_ value: T) -> String? {
    guard let data = try? JSONEncoder().encode(value) else { return nil }
    return String(data: data, encoding: .utf8)
}
