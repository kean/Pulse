// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

extension ConsoleMessageSearchCriteria {

    static func update(
        request: NSFetchRequest<NSManagedObject>,
        filterTerm: String,
        shared: ConsoleFilters,
        criteria: ConsoleMessageSearchCriteria,
        filters: [ConsoleSearchFilter],
        isOnlyErrors: Bool
    ) {
        var predicates = [NSPredicate]()

        if shared.dates.isEnabled {
            if let startDate = shared.dates.startDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
            }
            if let endDate = shared.dates.endDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
            }
        }

        if shared.filters.isEnabled {
            if shared.filters.inOnlyPins {
                predicates.append(NSPredicate(format: "isPinned == YES"))
            }
        }

        if isOnlyErrors {
            predicates.append(NSPredicate(format: "level IN %@", [LoggerStore.Level.critical, .error].map { $0.rawValue }))
        }

        if criteria.logLevels.isEnabled {
            if criteria.logLevels.levels.count != LoggerStore.Level.allCases.count {
                predicates.append(NSPredicate(format: "level IN %@", Array(criteria.logLevels.levels.map { $0.rawValue })))
            }
        }

        if criteria.labels.isEnabled {
            if let focusedLabel = criteria.labels.focused {
                predicates.append(NSPredicate(format: "label.name == %@", focusedLabel))
            } else if !criteria.labels.hidden.isEmpty {
                predicates.append(NSPredicate(format: "NOT label.name IN %@", Array(criteria.labels.hidden)))
            }
        }

        if filterTerm.count > 1 {
            predicates.append(NSPredicate(format: "text CONTAINS[cd] %@", filterTerm))
        }

        if criteria.isFiltersEnabled {
            for filter in filters where !filter.value.isEmpty {
                if let predicate = filter.makePredicate() {
                    predicates.append(predicate)
                } else {
                    // Have to be done in code
                }
            }
        }

        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
