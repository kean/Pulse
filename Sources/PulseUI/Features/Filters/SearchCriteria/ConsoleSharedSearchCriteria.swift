// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

struct ConsoleSharedSearchCriteria: Hashable {
    var dates = ConsoleDatesFilter.default
#if os(tvOS) || os(watchOS)
    var quickDatesFilter: ConsoleDatesQuickFilter = .all
#endif
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

#if os(tvOS) || os(watchOS)
enum ConsoleDatesQuickFilter: String, Hashable, CaseIterable {
    case session
    case recent
    case today
    case all

    var title: String { rawValue.capitalized }

    func makeDateFilter() -> ConsoleDatesFilter? {
        switch self {
        case .session: return .session
        case .recent: return .recent
        case .today: return .today
        case .all: return nil
        }
    }
}
#endif

struct ConsoleGeneralFilters: Hashable {
    var isEnabled = true
    var inOnlyPins = false

    static let `default` = ConsoleGeneralFilters()
}
