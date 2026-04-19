// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

/// Filter the logs displayed in the console.
package struct ConsoleFilters: Hashable, Codable {
    package var shared = Shared()
    package var messages = Messages()
    package var network = Network()

    package init() {}

    package struct Shared: Hashable, Codable {
        package var dates = Dates()

        package init() {}
    }

    package struct Messages: Hashable, Codable {
        package var logLevels = LogLevels()
        package var labels = Labels()
        package var custom = CustomMessageFilters()

        package init() {}
    }

    package struct Network: Hashable, Codable {
        package var host = Host()
        package var url = URL()
        package var custom = CustomNetworkFilters()
        package var response = Response()
        package var request = Request()
        package var networking = Networking()

        package init() {}
    }
}

package protocol ConsoleFilterProtocol: Hashable, Codable {
    init()
    var isDefault: Bool { get }
    var title: String { get }
    var description: String? { get }
}

extension ConsoleFilterProtocol {
    package var isDefault: Bool { self == Self() }
}

package protocol ConsoleFilterGroupProtocol: ConsoleFilterProtocol {
    var isEnabled: Bool { get set }
}

extension ConsoleFilters {
    package struct Dates: Hashable, Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var startDate: Date?
        package var endDate: Date?

        package init() {}

        private init(startDate: Date, endDate: Date? = nil) {
            self.startDate = startDate
            self.endDate = endDate
        }

        package static var last30Minutes: Dates {
            Dates(startDate: Date().addingTimeInterval(-1800))
        }

        package static var lastHour: Dates {
            Dates(startDate: Date().addingTimeInterval(-3600))
        }

        package static var today: Dates {
            Dates(startDate: Calendar.current.startOfDay(for: Date()))
        }

        package static var yesterday: Dates {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
            return Dates(startDate: startOfYesterday, endDate: startOfToday)
        }
    }

    package struct LogLevels: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var levels: Set<LoggerStore.Level> = Set(LoggerStore.Level.allCases)
            .subtracting([LoggerStore.Level.trace])

        package init() {}
    }

    package struct Labels: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var hidden: Set<String> = []
        package var focused: String?

        package init() {}
    }

    package struct Host: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var hidden: Set<String> = []
        package var focused: String?

        package init() {}
    }

    package struct URL: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var hidden: Set<String> = []
        package var focused: String?

        package init() {}
    }
}

package enum ConsoleFilterLogicalOperator: Hashable, Codable {
    case and
    case or
}

extension ConsoleFilters {
    package struct CustomMessageFilters: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var filters: [ConsoleCustomFilter] = [.defaultMessageFilter()]
        package var logicalOperator: ConsoleFilterLogicalOperator = .and

        package init() {}
    }

    package struct CustomNetworkFilters: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var filters: [ConsoleCustomFilter] = [.defaultNetworkFilter()]
        package var logicalOperator: ConsoleFilterLogicalOperator = .and

        package init() {}
    }

    package struct Response: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var statusCode = StatusCode()
        package var contentType = ContentType()
        package var responseSize = ResponseSize()
        package var duration = Duration()

        package init() {}
    }

    package struct StatusCode: Hashable, Codable, ConsoleFilterProtocol {
        package var range: ValuesRange<String> = .empty

        package init() {}
    }

    package struct ResponseSize: Hashable, Codable, ConsoleFilterProtocol {
        package var range: ValuesRange<String> = .empty
        package var unit: MeasurementUnit = .kilobytes

        package var byteCountRange: ValuesRange<Int64?> {
            ValuesRange(lowerBound: byteCount(from: range.lowerBound),
                        upperBound: byteCount(from: range.upperBound))
        }

        private func byteCount(from string: String) -> Int64? {
            Int64(string).map { $0 * unit.multiplier }
        }

        package enum MeasurementUnit: Identifiable, CaseIterable, Codable {
            case bytes, kilobytes, megabytes

            package var title: String {
                switch self {
                case .bytes: return "Bytes"
                case .kilobytes: return "KB"
                case .megabytes: return "MB"
                }
            }

            package var multiplier: Int64 {
                switch self {
                case .bytes: return 1
                case .kilobytes: return 1024
                case .megabytes: return 1024 * 1024
                }
            }

            package var id: MeasurementUnit { self }
        }

        package init() {}
    }

    package struct Duration: Hashable, Codable, ConsoleFilterProtocol {
        package var range: ValuesRange<String> = .empty
        package var unit: Unit = .seconds

        package var durationRange: ValuesRange<TimeInterval?> {
            ValuesRange(lowerBound: TimeInterval(range.lowerBound).map(unit.convert),
                        upperBound: TimeInterval(range.upperBound).map(unit.convert))
        }

        package enum Unit: Identifiable, CaseIterable, Codable {
            case minutes
            case seconds
            case milliseconds

            package var title: String {
                switch self {
                case .minutes: return "Min"
                case .seconds: return "Sec"
                case .milliseconds: return "ms"
                }
            }

            package func convert(_ value: TimeInterval) -> TimeInterval {
                switch self {
                case .minutes: return value * 60
                case .seconds: return value
                case .milliseconds: return value / 1000
                }
            }

            package var id: Unit { self }
        }

        package init() {}
    }

    package struct ContentType: Hashable, Codable, ConsoleFilterProtocol {
        package var contentType = ContentType.any

        package init() {}

        package enum ContentType: String, CaseIterable, Codable {
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

    package struct Request: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var httpMethod: HTTPMethodFilter = .any
        package var requestSize = ResponseSize()

        package init() {}

        package enum HTTPMethodFilter: Hashable, Codable {
            case any
            case some(HTTPMethod)
        }
    }

    package struct Networking: Codable, ConsoleFilterGroupProtocol {
        package var isEnabled = true
        package var isRedirect = false
        package var source: Source = .any
        package var taskType: TaskType = .any
        package var requestState: RequestState = .any

        package init() {}

        package enum Source: CaseIterable, Codable {
            case any
            case network
            case cache

            package var title: String {
                switch self {
                case .any: return "Any"
                case .cache: return "Cache"
                case .network: return "Network"
                }
            }
        }

        package enum TaskType: Hashable, Codable {
            case any
            case some(NetworkLogger.TaskType)
        }

        package enum RequestState: Hashable, CaseIterable, Codable {
            case any
            case pending
            case success
            case failure

            package var title: String {
                switch self {
                case .any: return "Any"
                case .pending: return "Pending"
                case .success: return "Success"
                case .failure: return "Failure"
                }
            }
        }
    }
}

// MARK: - Filter Titles & Descriptions

extension ConsoleFilters.Dates {
    package var title: String { "Time Period" }
    package var description: String? { nil }
}

extension ConsoleFilters.LogLevels {
    package var title: String { "Log Levels" }
    package var description: String? {
        let defaultLevels = Self().levels
        guard levels != defaultLevels else { return nil }
        if levels.count == 1, let only = levels.first {
            return "\(only.name) only"
        } else if levels.isEmpty {
            return "no levels"
        }
        return "\(levels.count) levels"
    }
}

extension ConsoleFilters.Labels {
    package var title: String { "Labels" }
    package var description: String? {
        if let label = focused, !label.isEmpty {
            return label
        } else if !hidden.isEmpty {
            return "−\(hidden.count) label\(hidden.count == 1 ? "" : "s")"
        }
        return nil
    }
}

extension ConsoleFilters.Host {
    package var title: String { "Hosts" }
    package var description: String? {
        if let host = focused, !host.isEmpty {
            return host
        } else if !hidden.isEmpty {
            return "−\(hidden.count) host\(hidden.count == 1 ? "" : "s")"
        }
        return nil
    }
}

extension ConsoleFilters.URL {
    package var title: String { "URL" }
    package var description: String? {
        if let url = focused, !url.isEmpty {
            return url
        } else if !hidden.isEmpty {
            return "−\(hidden.count) URL\(hidden.count == 1 ? "" : "s")"
        }
        return nil
    }
}

extension ConsoleFilters.CustomMessageFilters {
    package var title: String { "Custom Filters" }
    package var description: String? {
        let active = filters.filter { !$0.value.isEmpty }
        guard let first = active.first else { return nil }
        return "\(first.fieldTitle): \(first.value)"
    }
}

extension ConsoleFilters.CustomNetworkFilters {
    package var title: String { "Custom Filters" }
    package var description: String? {
        let active = filters.filter { !$0.value.isEmpty }
        guard let first = active.first else { return nil }
        return "\(first.fieldTitle): \(first.value)"
    }
}

extension ConsoleFilters.StatusCode {
    package var title: String { "Status Code" }
    package var description: String? {
        switch (range.lowerBound.isEmpty, range.upperBound.isEmpty) {
        case (false, false): return "\(range.lowerBound)–\(range.upperBound)"
        case (false, true): return "≥\(range.lowerBound)"
        case (true, false): return "≤\(range.upperBound)"
        case (true, true): return nil
        }
    }
}

extension ConsoleFilters.ContentType {
    package var title: String { "Content Type" }
    package var description: String? {
        contentType != .any ? contentType.rawValue : nil
    }
}

extension ConsoleFilters.ResponseSize {
    package var title: String { "Size" }
    package var description: String? {
        switch (range.lowerBound.isEmpty, range.upperBound.isEmpty) {
        case (false, false): return "\(range.lowerBound)–\(range.upperBound) \(unit.title)"
        case (false, true): return "≥\(range.lowerBound) \(unit.title)"
        case (true, false): return "≤\(range.upperBound) \(unit.title)"
        case (true, true): return nil
        }
    }
}

extension ConsoleFilters.Duration {
    package var title: String { "Duration" }
    package var description: String? {
        switch (range.lowerBound.isEmpty, range.upperBound.isEmpty) {
        case (false, false): return "\(range.lowerBound)–\(range.upperBound) \(unit.title)"
        case (false, true): return "≥\(range.lowerBound) \(unit.title)"
        case (true, false): return "≤\(range.upperBound) \(unit.title)"
        case (true, true): return nil
        }
    }
}

extension ConsoleFilters.Response {
    package var title: String { "Response" }
    package var description: String? {
        let parts = [statusCode.description, contentType.description, responseSize.description, duration.description].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension ConsoleFilters.Request {
    package var title: String { "Request" }
    package var description: String? {
        if case .some(let method) = httpMethod {
            return method.rawValue
        }
        return nil
    }
}

extension ConsoleFilters.Networking {
    package var title: String { "Networking" }
    package var description: String? {
        if requestState != .any {
            return requestState.title
        }
        return nil
    }
}

// MARK: - Summary

extension ConsoleFilters {
    /// The all-defaults instance, cached so callers comparing against the
    /// empty state don't pay the allocation cost on every check.
    private static let empty = ConsoleFilters()

    /// `true` when every section equals the all-defaults instance.
    package var isDefault: Bool { self == Self.empty }

    /// The mode-relevant filter groups, excluding sessions (context-specific).
    package func filters(for mode: ConsoleMode) -> [any ConsoleFilterProtocol] {
        var result: [any ConsoleFilterProtocol]
        if mode == .network {
            result = [network.custom, network.response.statusCode, network.response.contentType, network.response.responseSize, network.response.duration, network.request, network.host, network.url, network.networking]
        } else {
            result = [messages.custom, messages.logLevels, messages.labels]
        }
        result.append(shared.dates)
        return result
    }

    /// Number of filter sections that differ from defaults for the given mode.
    package func activeFilterCount(for mode: ConsoleMode) -> Int {
        filters(for: mode).filter { !$0.isDefault }.count
    }

    /// A short, mode-aware summary of the active filters, suitable for a recent
    /// filter chip. Returns `nil` when nothing meaningful is active.
    package func summary(for mode: ConsoleMode) -> String? {
        let segments = filters(for: mode).compactMap { $0.description }
        guard !segments.isEmpty else { return nil }
        let head = segments.prefix(3).joined(separator: " · ")
        let extra = segments.count > 3 ? " +\(segments.count - 2)" : ""
        return head + extra
    }

    /// A longer-form description listing every active predicate, used as a
    /// subtitle in the recent filters list. Returns `nil` when there are no
    /// extra segments beyond the summary.
    package func detail(for mode: ConsoleMode) -> String? {
        let segments = filters(for: mode).compactMap { $0.description }
        guard segments.count > 1 else { return nil }
        return segments.joined(separator: " · ")
    }
}
