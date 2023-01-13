// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

#warning("TODO: remove all the redundant defaults")
#warning("TODO: move isOnlyErrors here ?")
struct ConsoleSearchCriteria: Hashable {
    var shared = Shared()
    var messages = Messages()
    var network = Network()

    struct Shared: Hashable {
        var dates = Dates.default
        var general = General.default
    }

    struct Messages: Hashable {
        var logLevels: LogLevels = .default
        var labels: Labels = .default
        var custom = CustomMessageFilters.default
    }

    struct Network: Hashable {
        var response = Response.default
        var host = Host.default
        var networking = Networking.default
        var custom = CustomNetworkFilters.default
    }

    static let `default` = ConsoleSearchCriteria()
}

protocol ConsoleFilterProtocol: Hashable {
    var isEnabled: Bool { get set }
    static var `default`: Self { get }
}

extension ConsoleSearchCriteria {
    struct Dates: Hashable, ConsoleFilterProtocol {
        var isEnabled = true

        var startDate: Date?
        var endDate: Date?

        static let `default` = Dates()

        static var today: Dates {
            Dates(startDate: Calendar.current.startOfDay(for: Date()))
        }

        static var recent: Dates {
            Dates(startDate: Date().addingTimeInterval(-1200))
        }

        static var session: Dates {
            Dates(startDate: LoggerStore.launchDate)
        }
    }

    struct General: ConsoleFilterProtocol {
        var isEnabled = true
        var inOnlyPins = false

        static let `default` = General()
    }

    struct LogLevels: ConsoleFilterProtocol {
        var isEnabled = true
        var levels: Set<LoggerStore.Level> = Set(LoggerStore.Level.allCases)
            .subtracting([LoggerStore.Level.trace])

        static let `default` = LogLevels()
    }

    struct Labels: ConsoleFilterProtocol {
        var isEnabled = true
        var hidden: Set<String> = []
        var focused: String?

        static let `default` = Labels()
    }

    struct CustomMessageFilters: ConsoleFilterProtocol {
        var isEnabled = true
        var filters: [ConsoleCustomMessageFilter] = [.default]

        static let `default` = CustomMessageFilters()
    }

    struct Response: ConsoleFilterProtocol {
        var isEnabled = true
        var statusCode = StatusCode()
        var contentType = ContentType()
        var responseSize = ResponseSize()
        var duration = Duration()

        static let `default` = Response()
    }

    struct StatusCode: Hashable {
        var range: ValuesRange<String> = .empty
    }

    struct ResponseSize: Hashable {
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

    struct Duration: Hashable {
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

    struct Host: ConsoleFilterProtocol {
        var isEnabled = true
        var ignoredHosts: Set<String> = []

        static let `default` = Host()
    }

    struct ContentType: Hashable {
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

    struct Networking: ConsoleFilterProtocol {
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

        static let `default` = Networking()
    }

    struct CustomNetworkFilters: ConsoleFilterProtocol {
        var isEnabled = true
        var filters: [ConsoleCustomNetworkFilter] = [.default]

        static var `default`: CustomNetworkFilters { CustomNetworkFilters() }
    }
}
