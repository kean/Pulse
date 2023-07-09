// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

/// Allows you to control Pulse appearance and other settings programmatically.
public final class UserSettings: ObservableObject {
    public static let shared = UserSettings()

    @AppStorage("com.github.kean.pulse.console.cell.line.limit")
    public var lineLimit: Int = 4

    @AppStorage("com.github.kean.pulse.link.detection")
    public var isLinkDetectionEnabled = false

    @AppStorage("com.github.kean.pulse.sharing.output")
    public var sharingOutput: ShareStoreOutput = .store

    /// HTTP headers to display in a Console.
    public var displayHeaders: [String] {
        get {
            let data = rawDisplayHeaders.data(using: .utf8) ?? Data()
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            rawDisplayHeaders = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    @AppStorage("com.github.kean.pulse.display.headers")
    var rawDisplayHeaders: String = "[]"
}
