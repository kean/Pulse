// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import Foundation

enum ConsoleSearchScope: Equatable, Hashable, Codable, CaseIterable {
    // MARK: Logs
    case message
    case metadata

    // MARK: Network
    case url
    case originalRequestHeaders
    case currentRequestHeaders
    case requestBody
    case responseHeaders
    case responseBody

    var isDisplayedInResults: Bool {
        switch self {
        case .message, .url:
            return false
        case .metadata, .originalRequestHeaders, .currentRequestHeaders, .requestBody, .responseHeaders, .responseBody:
            return true
        }
    }

    static let messageScopes: [ConsoleSearchScope] = [
        .message,
        .metadata
    ]

    static let networkScopes: [ConsoleSearchScope] = [
        .url,
        .originalRequestHeaders,
        .currentRequestHeaders,
        .requestBody,
        .responseHeaders,
        .responseBody
    ]

    var title: String {
        switch self {
        case .url: return "URL"
        case .originalRequestHeaders: return "Original Request Headers"
        case .currentRequestHeaders: return "Current Request Headers"
        case .requestBody: return "Request Body"
        case .responseHeaders: return "Response Headers"
        case .responseBody: return "Response Body"
        case .message: return "Message"
        case .metadata: return "Metadata"
        }
    }
}

#endif
