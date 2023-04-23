// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

extension ConsoleFilers {
    static func makeMessagePredicates(
        criteria: ConsoleFilers,
        isOnlyErrors: Bool
    ) -> NSPredicate? {
        var predicates = [NSPredicate]()
        if isOnlyErrors {
            predicates.append(NSPredicate(format: "level IN %@", [LoggerStore.Level.critical, .error].map { $0.rawValue }))
        }
        predicates += makePredicates(for: criteria.shared)
        predicates += makePredicates(for: criteria.messages)
        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    static func makeNetworkPredicates(
        criteria: ConsoleFilers,
        isOnlyErrors: Bool
    ) -> NSPredicate? {
        var predicates = [NSPredicate]()
        if isOnlyErrors {
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.failure.rawValue))
        }
        predicates += makePredicates(for: criteria.shared, isNetwork: true)
        predicates += makePredicates(for: criteria.network)
        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

private func makePredicates(for criteria: ConsoleFilers.Shared, isNetwork: Bool = false) -> [NSPredicate] {
    var predicates = [NSPredicate]()

    if criteria.sessions.isEnabled && !criteria.sessions.selection.isEmpty {
        predicates.append(NSPredicate(format: "session IN %@", criteria.sessions.selection))
    }

    if criteria.dates.isEnabled {
        if let startDate = criteria.dates.startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
        }
        if let endDate = criteria.dates.endDate {
            predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
        }
    }

    return predicates
}

private func makePredicates(for criteria: ConsoleFilers.Messages) -> [NSPredicate] {
    var predicates = [NSPredicate]()

    if criteria.logLevels.isEnabled {
        if criteria.logLevels.levels.count != LoggerStore.Level.allCases.count {
            predicates.append(NSPredicate(format: "level IN %@", Array(criteria.logLevels.levels.map { $0.rawValue })))
        }
    }

    if criteria.labels.isEnabled {
        if let focusedLabel = criteria.labels.focused {
            predicates.append(NSPredicate(format: "label == %@", focusedLabel))
        } else if !criteria.labels.hidden.isEmpty {
            predicates.append(NSPredicate(format: "NOT label IN %@", Array(criteria.labels.hidden)))
        }
    }

#if os(iOS) || os(macOS)
    if criteria.custom.isEnabled {
        for filter in criteria.custom.filters where !filter.value.isEmpty {
            if let predicate = filter.makePredicate() {
                predicates.append(predicate)
            } else {
                // Have to be done in code
            }
        }
    }
#endif

    return predicates
}

private func makePredicates(for criteria: ConsoleFilers.Network) -> [NSPredicate] {
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
        predicates.append(NSPredicate(format: "NOT host IN %@", criteria.host.ignoredHosts))
    }

#if os(iOS) || os(macOS)
    if criteria.custom.isEnabled {
        for filter in criteria.custom.filters where !filter.value.isEmpty {
            if let predicate = filter.makePredicate() {
                predicates.append(predicate)
            } else {
                // Have to be done in code
            }
        }
    }
#endif

    return predicates
}
