// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

struct ConsoleNetworkSearchCriteria: Hashable {
    var isFiltersEnabled = true

    var response = ResponseFilter.default
    var host = HostFilter.default
    var networking = NetworkingFilter.default

    static let `default` = ConsoleNetworkSearchCriteria()

    var isDefault: Bool {
        self == ConsoleNetworkSearchCriteria.default
    }

    struct ResponseFilter: Hashable {
        var isEnabled = true
        var statusCode = StatusCodeFilter()
        var contentType = ContentTypeFilter()
        var responseSize = ResponseSizeFilter()
        var duration = DurationFilter()

        static let `default` = ResponseFilter()
    }

    struct StatusCodeFilter: Hashable {
        var range: ValuesRange<String> = .empty
    }

    struct ResponseSizeFilter: Hashable {
        var range: ValuesRange<String> = .empty
        var unit: MeasurementUnit = .kilobytes

        var byteCountRange: ValuesRange<Int64?> {
            ValuesRange(lowerBound: byteCount(from: range.lowerBound),
                        upperBound: byteCount(from: range.upperBound))
        }

        private func byteCount(from string: String) -> Int64? {
            Int64(string).map { $0 * unit.multiplier }
        }

        enum MeasurementUnit: Identifiable, CaseIterable {
            case bytes, kilobytes, megabytes

            var title: String {
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

            var id: MeasurementUnit { self }
        }
    }

    struct DurationFilter: Hashable {
        var range: ValuesRange<String> = .empty
        var unit: Unit = .seconds

        var durationRange: ValuesRange<TimeInterval?> {
            ValuesRange(lowerBound: TimeInterval(range.lowerBound).map(unit.convert),
                        upperBound: TimeInterval(range.upperBound).map(unit.convert))
        }

        enum Unit: Identifiable, CaseIterable {
            case minutes
            case seconds
            case milliseconds

            var title: String {
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

            var id: Unit { self }
        }
    }

    struct HostFilter: Hashable {
        var isEnabled = true
        var ignoredHosts: Set<String> = []

        static let `default` = HostFilter()
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

        enum Source: CaseIterable {
            case any
            case network
            case cache

            var title: String {
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

final class NetworkSearchFilter: ObservableObject, Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
    @Published var field: Field
    @Published var match: Match
    @Published var value: String

    static var `default`: NetworkSearchFilter {
        NetworkSearchFilter(field: .url, match: .contains, value: "")
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
