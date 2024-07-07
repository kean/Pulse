// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

/// Filter the logs displayed in the console.
public struct ConsoleFilers: Hashable {
    public var shared = Shared()
    public var messages = Messages()
    public var network = Network()

    public struct Shared: Hashable {
        public var sessions = Sessions()
        public var dates = Dates()

        public init() {}
    }

    public struct Messages: Hashable {
        public var logLevels = LogLevels()
        public var labels = Labels()
#if PULSE_STANDALONE_APP
        public var custom = CustomMessageFilters()
#endif

        public init() {}
    }

    public struct Network: Hashable {
        public var host = Host()
        public var url = URL()
#if PULSE_STANDALONE_APP
        public var custom = CustomNetworkFilters()
        public var response = Response()
        public var networking = Networking()
#endif

        public init() {}
    }
}

public protocol ConsoleFilterProtocol: Hashable {
    var isEnabled: Bool { get set }
    init() // Initializes with the default values
}

extension ConsoleFilers {
    public struct Sessions: Hashable, ConsoleFilterProtocol {
        public var isEnabled = true
        public var selection: Set<UUID> = []
        public init() {}
    }

    public struct Dates: Hashable, ConsoleFilterProtocol {
        public var isEnabled = true
        public var startDate: Date?
        public var endDate: Date?

        public init() {}

        public init(startDate: Date? = nil, endDate: Date? = nil) {
            self.startDate = startDate
            self.endDate = endDate
        }

        public static var today: Dates {
            Dates(startDate: Calendar.current.startOfDay(for: Date()))
        }

        public static var recent: Dates {
            Dates(startDate: Date().addingTimeInterval(-1200))
        }
    }

    public struct LogLevels: ConsoleFilterProtocol {
        public var isEnabled = true
        public var levels: Set<LoggerStore.Level> = Set(LoggerStore.Level.allCases)
            .subtracting([LoggerStore.Level.trace])
        public init() {}
    }

    public struct Labels: ConsoleFilterProtocol {
        public var isEnabled = true
        public var hidden: Set<String> = []
        public var focused: String?
        public init() {}
    }

    public struct Host: ConsoleFilterProtocol {
        public var isEnabled = true
        public var hidden: Set<String> = []
        public var focused: String?
        public init() {}
    }

    public struct URL: ConsoleFilterProtocol {
        public var isEnabled = true
        public var hidden: Set<String> = []
        public var focused: String?
        public init() {}
    }
}
