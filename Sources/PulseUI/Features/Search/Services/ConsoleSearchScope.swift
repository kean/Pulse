// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation

package enum ConsoleSearchScope: String, Equatable, Hashable, Codable, CaseIterable {
    // MARK: Logs
    case message
    case metadata

    // MARK: Network
    case url
    case query
    case requestHeaders
    case requestBody
    case responseHeaders
    case responseBody

    package var isDisplayedInResults: Bool {
        switch self {
        case .message, .url:
            return false
        case .metadata, .query, .requestHeaders, .requestBody, .responseHeaders, .responseBody:
            return true
        }
    }

    package static let messageScopes: [ConsoleSearchScope] = [
        .message,
        .metadata
    ]

    package static let networkScopes: [ConsoleSearchScope] = [
        .url,
        .responseBody,
        .requestBody,
        .query,
        .responseHeaders,
        .requestHeaders
    ]

    package var title: String {
        switch self {
        case .url: return "URL"
        case .query: return "Query"
        case .requestHeaders: return "Request Headers"
        case .requestBody: return "Request Body"
        case .responseHeaders: return "Response Headers"
        case .responseBody: return "Response Body"
        case .message: return "Message"
        case .metadata: return "Metadata"
        }
    }

    /// The default scopes selected when search opens for a given mode.
    package static func defaultScopes(for mode: ConsoleMode) -> [ConsoleSearchScope] {
        (mode.hasLogs ? [.message] : []) +
        (mode.hasNetwork ? [.url, .responseBody] : [])
    }

    /// The full list of scopes available for a given mode.
    package static func allScopes(for mode: ConsoleMode) -> [ConsoleSearchScope] {
        (mode.hasLogs ? messageScopes : []) +
        (mode.hasNetwork ? networkScopes : [])
    }

    // MARK: Persistence

    private static func storageKey(for mode: ConsoleMode) -> String {
        "com.github.kean.pulse.console.searchScopes.\(mode.rawValue)"
    }

    package static func loadPersistedScopes(for mode: ConsoleMode) -> Set<ConsoleSearchScope> {
        guard let raw = UserDefaults.standard.string(forKey: storageKey(for: mode)),
              let data = raw.data(using: .utf8),
              let stored = try? JSONDecoder().decode([ConsoleSearchScope].self, from: data) else {
            return Set(defaultScopes(for: mode))
        }
        return Set(stored).intersection(allScopes(for: mode))
    }

    package static func savePersistedScopes(_ scopes: Set<ConsoleSearchScope>, for mode: ConsoleMode) {
        guard let data = try? JSONEncoder().encode(Array(scopes)),
              let raw = String(data: data, encoding: .utf8) else {
            return
        }
        UserDefaults.standard.set(raw, forKey: storageKey(for: mode))
    }

    package static func clearPersistedScopes(for mode: ConsoleMode) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: mode))
    }
}

#endif
