// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

struct NetworkSearchCriteria: Hashable {
    var isFiltersEnabled = true

    var dates = DatesFilter.default
    var statusCode = StatusCodeFilter.default
    var host = HostFilter.default
    var duration = DurationFilter.default
    var contentType = ContentTypeFilter.default
    var redirect = RedirectFilter.default

    static let `default` = NetworkSearchCriteria()

    var isDefault: Bool {
        self == NetworkSearchCriteria.default
    }

    struct StatusCodeFilter: Hashable {
        var isEnabled = true
        var from: String = ""
        var to: String = ""

        static let `default` = StatusCodeFilter()
    }

    typealias DatesFilter = ConsoleSearchCriteria.DatesFilter

    struct HostFilter: Hashable {
        var isEnabled = true
        var value: String = ""

        static let `default` = HostFilter()
    }

    struct DurationFilter: Hashable {
        var isEnabled = true
        var from = DurationFilterPoint()
        var to = DurationFilterPoint()

        static let `default` = DurationFilter()
    }

    struct ContentTypeFilter: Hashable {
        var isEnabled = true
        var contentType = ContentType.any

        static let `default` = ContentTypeFilter()

        enum ContentType: String, CaseIterable {
            // common
            case any = ""
            case json = "application/json"
            case plain = "text/plain"
            case html = "text/html"

            // uncommon
            case javascript = "application/javascript"
            case css = "text/css"
            case csv = "text/csv"
            case xml = "text/xml"
            case pdf = "application/pdf"

            // image
            case gif = "image/gif"
            case jpeg = "image/jpeg"
            case png = "image/png"
            case webp = "image/webp"
            case anyImage = "image/"

            // video
            case anyVideo = "video/"
        }
    }

    struct RedirectFilter: Hashable {
        var isEnabled = true
        var isRedirect = false

        static let `default` = RedirectFilter()
    }
}

final class NetworkSearchFilter: ObservableObject, Hashable, Identifiable {
    let id: UUID
    @Published var field: Field
    @Published var match: Match
    @Published var value: String
    @Published var isEnabled: Bool

    // The actual filters had to be moved to the viewmodel
    static var defaultFilters: [NetworkSearchFilter] {
        [NetworkSearchFilter(id: UUID(), field: .url, match: .contains, value: "", isEnabled: true)]
    }

    var isDefault: Bool {
        field == .url && match == .contains && value == "" && isEnabled
    }

    init(id: UUID, field: Field, match: Match, value: String, isEnabled: Bool) {
        self.id = id
        self.field = field
        self.match = match
        self.value = value
        self.isEnabled = isEnabled
    }

    static func == (lhs: NetworkSearchFilter, rhs: NetworkSearchFilter) -> Bool {
        lhs.id == rhs.id &&
        lhs.field == rhs.field &&
        lhs.match == rhs.match &&
        lhs.value == rhs.value &&
        lhs.isEnabled == rhs.isEnabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(field)
        hasher.combine(match)
        hasher.combine(value)
        hasher.combine(isEnabled)
    }

    var isReady: Bool {
        isEnabled && !value.isEmpty
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
        case .requestHeader, .responseHeader, .requestBody, .responseBody: return true
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
        default: return nil
        }
    }
}

struct DurationFilterPoint: Hashable {
    var value: String = ""
    var unit: Unit = .seconds

    enum Unit {
        case minutes
        case seconds
        case milliseconds

        var localizedTitle: String {
            switch self {
            case .minutes: return "min"
            case .seconds: return "sec"
            case .milliseconds: return "ms"
            }
        }
    }

    var seconds: TimeInterval? {
        switch unit {
        case .minutes: return TimeInterval(value).map { $0 * 60 }
        case .seconds: return TimeInterval(value)
        case .milliseconds: return TimeInterval(value).map { $0 / 1000 }
        }
    }
}

private func decode<T: Decodable>(_ type: T.Type) -> (_ data: Data?) -> T? {
    {
        guard let data = $0 else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

private var cache = Cache<CacheKey, Any>(costLimit: Int.max, countLimit: 1000)

private struct CacheKey: Hashable {
    let id: NSManagedObjectID
    let code: Int
}

private var responseBodyCache = Cache<String, String?>(costLimit: 30_870_912, countLimit: 1000)

func evaluateProgrammaticFilters(_ filters: [NetworkSearchFilter], entity: LoggerNetworkRequestEntity, store: LoggerStore) -> Bool {
    var request: NetworkLoggerRequest? {
        let key = CacheKey(id: entity.objectID, code: 0)
        if let value = cache.value(forKey: key) as? NetworkLoggerRequest {
            return value
        }
        let value = entity.details.originalRequest.flatMap(decode(NetworkLoggerRequest.self))
        if let value = value {
            cache.set(value, forKey: key, ttl: 60)
        }
        return value
    }
    var response: NetworkLoggerResponse? {
        let key = CacheKey(id: entity.objectID, code: 1)
        if let value = cache.value(forKey: key) as? NetworkLoggerResponse {
            return value
        }
        let value = entity.details.response.flatMap(decode(NetworkLoggerResponse.self))
        if let value = value {
            cache.set(value, forKey: key, ttl: 60)
        }
        return value
    }

    func storedString(for key: String) -> String? {
        if let string = responseBodyCache.value(forKey: key) {
            return string
        }
        guard let data = store.getData(forKey: key), let string = String(data: data, encoding: .utf8) else {
            responseBodyCache.set(nil, forKey: key, cost: 0, ttl: 60) // Record miss
            return nil
        }
        responseBodyCache.set(string, forKey: key, cost: data.count, ttl: 60)
        return string
    }

    func isMatch(filter: NetworkSearchFilter) -> Bool {
        switch filter.field {
        case .requestHeader: return (request?.headers ?? [:]).contains { filter.matches(string: $0.key) || filter.matches(string: $0.value) }
        case .responseHeader: return (response?.headers ?? [:]).contains { filter.matches(string: $0.key) || filter.matches(string: $0.value) }
        case .requestBody: return filter.matches(string: entity.requestBodyKey.flatMap(storedString(for:)) ?? "")
        case .responseBody: return filter.matches(string: entity.responseBodyKey.flatMap(storedString(for:)) ?? "")
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

private let isNetworkMessagePredicate = NSPredicate(format: "request != nil")

extension NetworkSearchCriteria {
    static func update(request: NSFetchRequest<LoggerNetworkRequestEntity>, filterTerm: String, criteria: NetworkSearchCriteria, filters: [NetworkSearchFilter], isOnlyErrors: Bool, sessionId: String?) {
        var predicates = [NSPredicate]()

        if isOnlyErrors {
            predicates.append(NSPredicate(format: "requestState == %d", LoggerNetworkRequestEntity.State.failure.rawValue))
        }

        if criteria.dates.isCurrentSessionOnly, let sessionId = sessionId, !sessionId.isEmpty {
            predicates.append(NSPredicate(format: "session == %@", sessionId))
        }

        if criteria.dates.isEnabled {
            if criteria.dates.isStartDateEnabled, let startDate = criteria.dates.startDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
            }
            if criteria.dates.isEndDateEnabled, let endDate = criteria.dates.endDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
            }
        }

        if criteria.host.isEnabled, !criteria.host.value.isEmpty {
            predicates.append(NSPredicate(format: "host == %@", criteria.host.value))
        }

        if criteria.statusCode.isEnabled {
            if let value = Int(criteria.statusCode.from), value > 0 {
                predicates.append(NSPredicate(format: "statusCode >= %d", value))
            }
            if let value = Int(criteria.statusCode.to), value > 0 {
                predicates.append(NSPredicate(format: "statusCode <= %d", value))
            }
        }

        if criteria.duration.isEnabled {
            if let value = criteria.duration.from.seconds {
                predicates.append(NSPredicate(format: "duration >= %f", value))
            }
            if let value = criteria.duration.to.seconds {
                predicates.append(NSPredicate(format: "duration <= %f", value))
            }
        }

        if criteria.redirect.isEnabled && criteria.redirect.isRedirect {
            predicates.append(NSPredicate(format: "redirectCount >= 1"))
        }

        if criteria.contentType.isEnabled {
            switch criteria.contentType.contentType {
            case .any: break
            default: predicates.append(NSPredicate(format: "contentType CONTAINS %@", criteria.contentType.contentType.rawValue))
            }
        }

        if filterTerm.count > 1 {
            predicates.append(NSPredicate(format: "url CONTAINS[cd] %@", filterTerm))
        }

        if criteria.isFiltersEnabled {
            for filter in filters where filter.isReady {
                if let predicate = filter.makePredicate() {
                    predicates.append(predicate)
                } else {
                    // Have to be done in code
                }
            }
        }

        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
