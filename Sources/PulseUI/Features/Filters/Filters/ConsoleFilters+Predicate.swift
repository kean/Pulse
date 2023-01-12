// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

#warning("TODO: refactor")
extension ConsoleFilters {
    static func update(
        request: NSFetchRequest<NSManagedObject>,
        filterTerm: String,
        criteria: ConsoleFilters,
        isOnlyErrors: Bool
    ) {
        var predicates = [NSPredicate]()

        if criteria.shared.dates.isEnabled {
            if let startDate = criteria.shared.dates.startDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
            }
            if let endDate = criteria.shared.dates.endDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
            }
        }

        if criteria.shared.general.isEnabled {
            if criteria.shared.general.inOnlyPins {
                predicates.append(NSPredicate(format: "isPinned == YES"))
            }
        }

        if isOnlyErrors {
            predicates.append(NSPredicate(format: "level IN %@", [LoggerStore.Level.critical, .error].map { $0.rawValue }))
        }

        if criteria.messages.logLevels.isEnabled {
            if criteria.messages.logLevels.levels.count != LoggerStore.Level.allCases.count {
                predicates.append(NSPredicate(format: "level IN %@", Array(criteria.messages.logLevels.levels.map { $0.rawValue })))
            }
        }

        if criteria.messages.labels.isEnabled {
            if let focusedLabel = criteria.messages.labels.focused {
                predicates.append(NSPredicate(format: "label.name == %@", focusedLabel))
            } else if !criteria.messages.labels.hidden.isEmpty {
                predicates.append(NSPredicate(format: "NOT label.name IN %@", Array(criteria.messages.labels.hidden)))
            }
        }

        if filterTerm.count > 1 {
            predicates.append(NSPredicate(format: "text CONTAINS[cd] %@", filterTerm))
        }

        if criteria.messages.custom.isEnabled {
            for filter in criteria.messages.custom.filters where !filter.value.isEmpty {
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

extension ConsoleNetworkSearchCriteria {
    static func update(
        request: NSFetchRequest<NSManagedObject>,
        filterTerm: String,
        criteria: ConsoleFilters,
        isOnlyErrors: Bool
    ) {
        var predicates = [NSPredicate]()

        if isOnlyErrors {
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.failure.rawValue))
        }

        if criteria.shared.dates.isEnabled {
            if let startDate = criteria.shared.dates.startDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
            }
            if let endDate = criteria.shared.dates.endDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
            }
        }

        predicates += makePredicates(for: criteria.network)

        if filterTerm.count > 1 {
            predicates.append(NSPredicate(format: "url CONTAINS[cd] %@", filterTerm))
        }

        if criteria.shared.general.isEnabled {
            if criteria.shared.general.inOnlyPins {
                predicates.append(NSPredicate(format: "message.isPinned == YES"))
            }
        }

        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

private func makePredicates(for criteria: ConsoleFilters.Network) -> [NSPredicate] {
    var predicates = [NSPredicate]()

    if criteria.response.isEnabled {
        if let value = criteria.response.responseSize.byteCountRange.lowerBound {
            predicates.append(NSPredicate(format: "responseBodySize >= %d", value))
        }
        if let value = criteria.response.responseSize.byteCountRange.upperBound {
            predicates.append(NSPredicate(format: "responseBodySize <= %d", value))
        }
        if let value = Int(criteria.response.statusCode.range.lowerBound) {
            predicates.append(NSPredicate(format: "statusCode >= %d", value))
        }
        if let value = Int(criteria.response.statusCode.range.upperBound) {
            predicates.append(NSPredicate(format: "statusCode <= %d", value))
        }
        if let value = criteria.response.duration.durationRange.lowerBound {
            predicates.append(NSPredicate(format: "duration >= %f", value))
        }
        if let value = criteria.response.duration.durationRange.upperBound {
            predicates.append(NSPredicate(format: "duration <= %f", value))
        }
        switch criteria.response.contentType.contentType {
        case .any: break
        default: predicates.append(NSPredicate(format: "responseContentType CONTAINS %@", criteria.response.contentType.contentType.rawValue))
        }
    }

    if criteria.networking.isEnabled {
        if criteria.networking.isRedirect {
            predicates.append(NSPredicate(format: "redirectCount >= 1"))
        }
        switch criteria.networking.source {
        case .any:
            break
        case .network:
            predicates.append(NSPredicate(format: "isFromCache == NO"))
        case .cache:
            predicates.append(NSPredicate(format: "isFromCache == YES"))
        }
        if case .some(let taskType) = criteria.networking.taskType {
            predicates.append(NSPredicate(format: "taskType == %i", taskType.rawValue))
        }
    }

    if criteria.host.isEnabled, !criteria.host.ignoredHosts.isEmpty {
        predicates.append(NSPredicate(format: "NOT host.value IN %@", criteria.host.ignoredHosts))
    }

    if criteria.customNetworkFilters.isEnabled {
        for filter in criteria.customNetworkFilters.filters where !filter.value.isEmpty {
            if let predicate = filter.makePredicate() {
                predicates.append(predicate)
            } else {
                // Have to be done in code
            }
        }
    }

    return predicates
}
