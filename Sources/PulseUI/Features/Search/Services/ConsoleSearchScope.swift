// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation

enum ConsoleSearchScope: Equatable, Hashable, Codable, CaseIterable {
    case url
    case originalRequestHeaders
    case currentRequestHeaders
    case requestBody
    case responseHeaders
    case responseBody
    case message
    case metadata

    static let allEligibleScopes = ConsoleSearchScope.allCases.filter {
        $0 != .originalRequestHeaders && $0 != .message
    }

    var title: String {
        switch self {
        case .originalRequestHeaders: return "Request Headers"
        case .currentRequestHeaders: return "Request Headers"
        default: return fullTitle
        }
    }

    var fullTitle: String {
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
