// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

/// Allows you to control Pulse appearance and other settings programatically.
public final class UserSettings: ObservableObject {
    public static let shared = UserSettings()

    @AppStorage("com.github.kean.pulse.console.cell.line.limit")
    public var lineLimit: Int = 4

    @AppStorage("com.github.kean.pulse.link.detection")
    public var isLinkDetectionEnabled = false

    @AppStorage("com.github.kean.pulse.sharing.output")
    public var sharingOutput: ShareStoreOutput = .store

    @AppStorage("com.github.kean.pulse.display.headers")
    public var displayHeaders: [String] = []
}

// MARK: - Array + RawREpresentable

extension Array: RawRepresentable where Element: Codable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([Element].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}
