// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation

enum ConsoleSearchScope: Equatable, Hashable, Codable, CaseIterable {
    // MARK: Logs
    case message
    case metadata

    // MARK: Network
    case url
    case requestBody
    case responseBody

    var isDisplayedInResults: Bool {
        switch self {
        case .message, .url:
            return false
        case .metadata, .requestBody, .responseBody:
            return true
        }
    }

    static let messageScopes: [ConsoleSearchScope] = [
        .message,
        .metadata
    ]

    static let networkScopes: [ConsoleSearchScope] = [
        .url,
        .requestBody,
        .responseBody
    ]

    var title: String {
        switch self {
        case .url: return "URL"
        case .requestBody: return "Request Body"
        case .responseBody: return "Response Body"
        case .message: return "Message"
        case .metadata: return "Metadata"
        }
    }
}

#endif
