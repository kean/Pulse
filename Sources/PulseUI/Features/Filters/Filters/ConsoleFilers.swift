// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

/// Filter the logs displayed in the console.
struct ConsoleFilers: Hashable {
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
#if PULSE_STANDALONE_APP
        var custom = CustomMessageFilters()
#endif
    }

    struct Network: Hashable {
        var host = Host()
#if PULSE_STANDALONE_APP
        var custom = CustomNetworkFilters()
        var response = Response()
        var networking = Networking()
#endif
    }
}

protocol ConsoleFilterProtocol: Hashable {
    var isEnabled: Bool { get set }
    init() // Initializes with the default values
}

extension ConsoleFilers {
    struct Sessions: Hashable, ConsoleFilterProtocol {
        var isEnabled = true
        var selection: Set<UUID> = []
    }

    struct Dates: Hashable, ConsoleFilterProtocol {
        var isEnabled = true
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
        var isEnabled = true
        var levels: Set<LoggerStore.Level> = Set(LoggerStore.Level.allCases)
            .subtracting([LoggerStore.Level.trace])
    }

    struct Labels: ConsoleFilterProtocol {
        var isEnabled = true
        var hidden: Set<String> = []
        var focused: String?
    }

    struct Host: ConsoleFilterProtocol {
        var isEnabled = true
        var hidden: Set<String> = []
        var focused: String?
    }
}
