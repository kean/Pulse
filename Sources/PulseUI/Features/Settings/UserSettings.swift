// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

final class UserSettings: ObservableObject {
    static let shared = UserSettings()

    @AppStorage("console-cell-line-limit")
    var lineLimit: Int = 4

    @AppStorage("link-detection")
    var isLinkDetectionEnabled = false

    @AppStorage("sharing-output")
    var sharingOutput: ShareStoreOutput = .store

    @AppStorage("display-headers")
    var displayHeaders: [String] = []
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
