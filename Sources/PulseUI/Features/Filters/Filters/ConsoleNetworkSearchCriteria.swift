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
                case .minutes: return "Min"
                case .seconds: return "Sec"
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
