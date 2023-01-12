// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

struct ConsoleSharedSearchCriteria: Hashable {
    var dates = ConsoleDatesFilter.default
    var filters = ConsoleGeneralFilters.default
}

struct ConsoleDatesFilter: Hashable {
    var isEnabled = true

    var startDate: Date?
    var endDate: Date?

    static let `default` = ConsoleDatesFilter()

    static var today: ConsoleDatesFilter {
        ConsoleDatesFilter(startDate: Calendar.current.startOfDay(for: Date()))
    }

    static var recent: ConsoleDatesFilter {
        ConsoleDatesFilter(startDate: Date().addingTimeInterval(-1200))
    }

    static var session: ConsoleDatesFilter {
        ConsoleDatesFilter(startDate: LoggerStore.launchDate)
    }
}

struct ConsoleGeneralFilters: Hashable {
    var isEnabled = true
    var inOnlyPins = false

    static let `default` = ConsoleGeneralFilters()
}
