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

    if criteria.sessions.isEnabled, !criteria.sessions.selection.isEmpty {
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

#if PULSE_STANDALONE_APP
    predicates += makeStandalonePredicates(for: criteria)
#endif

    return predicates
}

private func makePredicates(for criteria: ConsoleFilers.Network) -> [NSPredicate] {
    var predicates = [NSPredicate]()

    if criteria.host.isEnabled {
        if let focusedHost = criteria.host.focused {
            predicates.append(NSPredicate(format: "host == %@", focusedHost))
        } else if !criteria.host.hidden.isEmpty {
            predicates.append(NSPredicate(format: "NOT host IN %@", Array(criteria.host.hidden)))
        }
    }

#if PULSE_STANDALONE_APP
    predicates += makeStandalonePredicates(for: criteria)
#endif

    return predicates
}
