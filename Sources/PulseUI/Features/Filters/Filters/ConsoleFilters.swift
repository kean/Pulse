// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

/// Filter the logs displayed in the console.
struct ConsoleFilters: Hashable {
    var shared = Shared()
    var messages = Messages()
    var network = Network()

    struct Shared: Hashable {
        var sessions = Sessions()
        var dates = Dates()
    }

    struct Messages: Hashable {
        var logLevels = LogLevels()
        var labels = Labels()
    }

    struct Network: Hashable {
        var host = Host()
        var url = URL()
    }
}

protocol ConsoleFilterProtocol: Hashable {
    init() // Initializes with the default values
}

extension ConsoleFilters {
    struct Sessions: Hashable, ConsoleFilterProtocol {
        var selection: Set<UUID> = []
    }

    struct Dates: Hashable, ConsoleFilterProtocol {
        var startDate: Date?
        var endDate: Date?

        static var today: Dates {
            Dates(startDate: Calendar.current.startOfDay(for: Date()))
        }

        static var recent: Dates {
            Dates(startDate: Date().addingTimeInterval(-1200))
        }
    }

    struct LogLevels: ConsoleFilterProtocol {
        var levels: Set<LoggerStore.Level> = Set(LoggerStore.Level.allCases)
            .subtracting([LoggerStore.Level.trace])
    }

    struct Labels: ConsoleFilterProtocol {
        var hidden: Set<String> = []
        var focused: String?
    }

    struct Host: ConsoleFilterProtocol {
        var hidden: Set<String> = []
        var focused: String?
    }

    struct URL: ConsoleFilterProtocol {
        var hidden: Set<String> = []
        var focused: String?
    }
}
