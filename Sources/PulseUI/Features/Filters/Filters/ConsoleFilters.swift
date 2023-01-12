// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine

struct ConsoleFilters: Hashable {
    var dates = Dates.default
    var filters = General.default
}

extension ConsoleFilters {
    struct Dates: Hashable {
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

    struct General: Hashable {
        var isEnabled = true
        var inOnlyPins = false

        static let `default` = General()
    }
}
