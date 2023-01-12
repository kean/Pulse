// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

extension ConsoleNetworkSearchCriteria {
    static func update(
        request: NSFetchRequest<NSManagedObject>,
        filterTerm: String,
        shared: ConsoleFilters,
        criteria: ConsoleNetworkSearchCriteria,
        isOnlyErrors: Bool
    ) {
        var predicates = [NSPredicate]()

        if isOnlyErrors {
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.failure.rawValue))
        }

        if shared.dates.isEnabled {
            if let startDate = shared.dates.startDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
            }
            if let endDate = shared.dates.endDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
            }
        }

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

        if filterTerm.count > 1 {
            predicates.append(NSPredicate(format: "url CONTAINS[cd] %@", filterTerm))
        }

        if shared.general.isEnabled {
            if shared.general.inOnlyPins {
                predicates.append(NSPredicate(format: "message.isPinned == YES"))
            }
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

        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
