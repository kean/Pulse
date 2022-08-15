// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

#if os(iOS) || os(macOS) || os(tvOS)

struct NetworkSearchCriteria: Hashable {
    var isFiltersEnabled = true

    var dates = DatesFilter.default
    var response = ResponseFilter.default
    var host = HostFilter.default
    var duration = DurationFilter.default
    var networking = NetworkingFilter.default

    static let `default` = NetworkSearchCriteria()

    var isDefault: Bool {
        self == NetworkSearchCriteria.default
    }

    struct ResponseFilter: Hashable {
        var isEnabled = true
        var statusCode = StatusCodeFilter()
        var contentType = ContentTypeFilter()
        var responseSize = ResponseSizeFilter()

        static let `default` = ResponseFilter()
    }

    struct StatusCodeFilter: Hashable {
        var from: String = ""
        var to: String = ""
    }

    struct ResponseSizeFilter: Hashable {
        var from: String = ""
        var to: String = ""
        var unit: MeasurementUnit = .kilobytes

        var fromBytes: Int64? {
            Int64(from).map { $0 * unit.multiplier }
        }

        var toBytes: Int64? {
            Int64(to).map { $0 * unit.multiplier }
        }

        enum MeasurementUnit: CaseIterable {
            case bytes, kilobytes, megabytes

            var localizedTitle: String {
                switch self {
                case .bytes: return "Bytes"
                case .kilobytes: return "KB"
                case .megabytes: return "MB"
                }
            }

            var multiplier: Int64 {
                switch self {
                case .bytes: return 1
                case .kilobytes: return 1024
                case .megabytes: return 1024 * 1024
                }
            }
        }
    }

    typealias DatesFilter = ConsoleSearchCriteria.DatesFilter

    struct HostFilter: Hashable {
        var isEnabled = true
        var values: Set<String> = []

        static let `default` = HostFilter()
    }

    struct DurationFilter: Hashable {
        var isEnabled = true
        var min: String = ""
        var max: String = ""
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

            func convert(_ value: TimeInterval) -> TimeInterval {
                switch self {
                case .minutes: return value * 60
                case .seconds: return value
                case .milliseconds: return value / 1000
                }
            }
        }

        var minSeconds: TimeInterval? {
            TimeInterval(min).map(unit.convert)
        }

        var maxSeconds: TimeInterval? {
            TimeInterval(max).map(unit.convert)
        }

        static let `default` = DurationFilter()
    }

    struct ContentTypeFilter: Hashable {
        var contentType = ContentType.any

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

    struct NetworkingFilter: Hashable {
        var isEnabled = true
        var isRedirect = false
        var source: Source = .any
        var taskType: TaskType = .any

        enum Source {
            case any
            case network
            case cache

            var localizedTitle: String {
                switch self {
                case .any: return "Any"
                case .cache: return "Cache"
                case .network: return "Network"
                }
            }
        }

        enum TaskType: Hashable {
            case any
            case some(NetworkLogger.TaskType)
        }

        static let `default` = NetworkingFilter()
    }
}

final class NetworkSearchFilter: ObservableObject, Hashable, Identifiable {
    let id: UUID
    @Published var field: Field
    @Published var match: Match
    @Published var value: String

    // The actual filters had to be moved to the viewmodel
    static let defaultFilters = [NetworkSearchFilter(id: UUID(), field: .url, match: .contains, value: "")]

    var isDefault: Bool {
        field == .url && match == .contains && value == ""
    }

    init(id: UUID, field: Field, match: Match, value: String) {
        self.id = id
        self.field = field
        self.match = match
        self.value = value
    }

    static func == (lhs: NetworkSearchFilter, rhs: NetworkSearchFilter) -> Bool {
        lhs.id == rhs.id &&
        lhs.field == rhs.field &&
        lhs.match == rhs.match &&
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(field)
        hasher.combine(match)
        hasher.combine(value)
    }

    var isReady: Bool {
        !value.isEmpty
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

func evaluateProgrammaticFilters(_ filters: [NetworkSearchFilter], entity: NetworkTaskEntity, store: LoggerStore) -> Bool {
    func isMatch(filter: NetworkSearchFilter) -> Bool {
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

extension NetworkSearchCriteria {
    static func update(request: NSFetchRequest<NetworkTaskEntity>, filterTerm: String, criteria: NetworkSearchCriteria, filters: [NetworkSearchFilter], isOnlyErrors: Bool, sessionId: UUID?) {
        var predicates = [NSPredicate]()

        if isOnlyErrors {
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.failure.rawValue))
        }

        if criteria.dates.isCurrentSessionOnly, let sessionId = sessionId {
            predicates.append(NSPredicate(format: "session == %@", sessionId as NSUUID))
        }

        if criteria.dates.isEnabled {
            if criteria.dates.isStartDateEnabled, let startDate = criteria.dates.startDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
            }
            if criteria.dates.isEndDateEnabled, let endDate = criteria.dates.endDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
            }
        }

        if criteria.response.isEnabled {
            if let value = criteria.response.responseSize.fromBytes {
                predicates.append(NSPredicate(format: "responseBodySize >= %d", value))
            }
            if let value = criteria.response.responseSize.toBytes {
                predicates.append(NSPredicate(format: "responseBodySize <= %d", value))
            }

            if let value = Int(criteria.response.statusCode.from), value > 0 {
                predicates.append(NSPredicate(format: "statusCode >= %d", value))
            }
            if let value = Int(criteria.response.statusCode.to), value > 0 {
                predicates.append(NSPredicate(format: "statusCode <= %d", value))
            }

            switch criteria.response.contentType.contentType {
            case .any: break
            default: predicates.append(NSPredicate(format: "responseContentType CONTAINS %@", criteria.response.contentType.contentType.rawValue))
            }
        }

        if criteria.duration.isEnabled {
            if let value = criteria.duration.minSeconds {
                predicates.append(NSPredicate(format: "duration >= %f", value))
            }
            if let value = criteria.duration.maxSeconds {
                predicates.append(NSPredicate(format: "duration <= %f", value))
            }
        }

        if criteria.networking.isEnabled {
            if criteria.networking.isRedirect {
                predicates.append(NSPredicate(format: "redirectCount >= 1"))
            }
            switch criteria.networking.source {
            case .any:
                break
            case .network:
                predicates.append(NSPredicate(format: "isFromCache == NO"))
            case .cache:
                predicates.append(NSPredicate(format: "isFromCache == YES"))
            }
            if case .some(let taskType) = criteria.networking.taskType {
                predicates.append(NSPredicate(format: "taskType == %i", taskType.rawValue))
            }
        }

        if criteria.host.isEnabled, !criteria.host.values.isEmpty {
            predicates.append(NSPredicate(format: "host IN %@", criteria.host.values))
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

#endif
