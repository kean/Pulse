// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

final class ConsoleCustomNetworkFilter: ObservableObject, Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
    @Published var field: Field
    @Published var match: Match
    @Published var value: String

    static var `default`: ConsoleCustomNetworkFilter {
        ConsoleCustomNetworkFilter(field: .url, match: .contains, value: "")
    }

    init(field: Field, match: Match, value: String) {
        self.field = field
        self.match = match
        self.value = value
    }

    enum Field {
        // Database
        case url
        case host
        case method
        case statusCode
        case errorCode

        // Programmatic
        case requestHeader
        case responseHeader
        case requestBody
        case responseBody

        var localizedTitle: String {
            switch self {
            case .url: return "URL"
            case .host: return "Host"
            case .method: return "Method"
            case .statusCode: return "Status Code"
            case .errorCode: return "Error Code"
            case .requestHeader: return "Request Headers"
            case .responseHeader: return "Response Headers"
            case .requestBody: return "Request Body"
            case .responseBody: return "Response Body"
            }
        }
    }

    enum Match {
        case equal // LIKE[c]
        case notEqual
        case contains
        case notContains
        case regex
        case beginsWith

        var localizedTitle: String {
            switch self {
            case .equal: return "Equal"
            case .notEqual: return "Not Equal"
            case .contains: return "Contains"
            case .notContains: return "Not Contains"
            case .regex: return "Regex"
            case .beginsWith: return "Begins With"
            }
        }
    }

    var isProgrammatic: Bool {
        switch field {
        case .requestBody, .responseBody: return true
        default: return false
        }
    }

    func makePredicate() -> NSPredicate? {
        guard let key = self.key else {
            return nil
        }
        switch match {
        case .equal: return NSPredicate(format: "\(key) LIKE[c] %@", value)
        case .notEqual: return NSPredicate(format: "NOT (\(key) LIKE[c] %@)", value)
        case .contains: return NSPredicate(format: "\(key) CONTAINS[c] %@", value)
        case .notContains: return NSPredicate(format: "NOT (\(key) CONTAINS[c] %@)", value)
        case .beginsWith: return NSPredicate(format: "\(key) BEGINSWITH[c] %@", value)
        case .regex: return NSPredicate(format: "\(key) MATCHES %@", value)
        }
    }

    func matches(string: String) -> Bool {
        switch match {
        case .equal: return string.caseInsensitiveCompare(value) == .orderedSame
        case .notEqual: return string.caseInsensitiveCompare(value) != .orderedSame
        case .contains: return string.firstRange(of: value, options: [.caseInsensitive]) != nil
        case .notContains: return string.firstRange(of: value, options: [.caseInsensitive]) == nil
        case .regex: return string.firstRange(of: value, options: [.caseInsensitive, .regularExpression]) != nil
        case .beginsWith: return string.firstRange(of: value, options: [.caseInsensitive, .anchored]) != nil
        }
    }

    private var key: String? {
        switch field {
        case .url: return "url"
        case .host: return "host"
        case .method: return "httpMethod"
        case .statusCode: return "statusCode"
        case .errorCode: return "errorCode"
        case .requestHeader: return "originalRequest.httpHeaders"
        case .responseHeader: return "response.httpHeaders"
        default: return nil
        }
    }
}

func evaluateProgrammaticFilters(_ filters: [ConsoleCustomNetworkFilter], entity: NetworkTaskEntity, store: LoggerStore) -> Bool {
    func isMatch(filter: ConsoleCustomNetworkFilter) -> Bool {
        switch filter.field {
        case .requestBody: return filter.matches(string: String(data: entity.requestBody?.data ?? Data(), encoding: .utf8) ?? "")
        case .responseBody: return filter.matches(string: String(data: entity.responseBody?.data ?? Data(), encoding: .utf8) ?? "")
        default: assertionFailure(); return false
        }
    }
    for filter in filters where filter.isProgrammatic {
        if !isMatch(filter: filter) {
            return false
        }
    }
    return true
}
