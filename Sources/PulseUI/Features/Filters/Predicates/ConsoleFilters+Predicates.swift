// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData

extension ConsoleFilters {
    package static func makeMessagePredicates(
        criteria: ConsoleFilters,
        sessions: Set<UUID>,
        isOnlyErrors: Bool
    ) -> NSPredicate? {
        var predicates = [NSPredicate]()
        if isOnlyErrors {
            predicates.append(NSPredicate(format: "level IN %@", [LoggerStore.Level.critical, .error].map { $0.rawValue }))
        }
        predicates += makePredicates(for: criteria.shared, sessions: sessions)
        predicates += makePredicates(for: criteria.messages)
        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    package static func makeNetworkPredicates(
        criteria: ConsoleFilters,
        sessions: Set<UUID>,
        isOnlyErrors: Bool
    ) -> NSPredicate? {
        var predicates = [NSPredicate]()
        if isOnlyErrors {
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.failure.rawValue))
        }
        predicates += makePredicates(for: criteria.shared, sessions: sessions, isNetwork: true)
        predicates += makePredicates(for: criteria.network)
        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

private func makePredicates(for criteria: ConsoleFilters.Shared, sessions: Set<UUID>, isNetwork: Bool = false) -> [NSPredicate] {
    var predicates = [NSPredicate]()

    if !sessions.isEmpty {
        predicates.append(NSPredicate(format: "session IN %@", sessions))
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

private func makePredicates(for criteria: ConsoleFilters.Messages) -> [NSPredicate] {
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

    return predicates + makeStandalonePredicates(for: criteria)
}

private func makePredicates(for criteria: ConsoleFilters.Network) -> [NSPredicate] {
    var predicates = [NSPredicate]()

    if criteria.host.isEnabled {
        if let focusedHost = criteria.host.focused {
            predicates.append(NSPredicate(format: "host == %@", focusedHost))
        } else if !criteria.host.hidden.isEmpty {
            predicates.append(NSPredicate(format: "NOT host IN %@", Array(criteria.host.hidden)))
        }
    }

    if criteria.url.isEnabled {
        if let focusedURL = criteria.url.focused {
            predicates.append(NSPredicate(format: "url == %@", focusedURL))
        } else if !criteria.url.hidden.isEmpty {
            predicates.append(NSPredicate(format: "NOT url IN %@", Array(criteria.url.hidden)))
        }
    }

    return predicates + makeStandalonePredicates(for: criteria)
}

private func makeStandalonePredicates(for criteria: ConsoleFilters.Messages) -> [NSPredicate] {
    if criteria.custom.isEnabled {
        let filterPredicates = criteria.custom.filters
            .filter { !$0.value.isEmpty && $0.isEnabled }
            .map { $0.makePredicate() }
        if !filterPredicates.isEmpty {
            switch criteria.custom.logicalOperator {
            case .and:
                return filterPredicates
            case .or:
                return [NSCompoundPredicate(orPredicateWithSubpredicates: filterPredicates)]
            }
        }
    }
    return []
}

private func makeStandalonePredicates(for criteria: ConsoleFilters.Network) -> [NSPredicate] {
    var predicates: [NSPredicate] = []
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

    if criteria.request.isEnabled {
        if case .some(let method) = criteria.request.httpMethod {
            predicates.append(NSPredicate(format: "httpMethod ==[c] %@", method.rawValue))
        }
        if let value = criteria.request.requestSize.byteCountRange.lowerBound {
            predicates.append(NSPredicate(format: "requestBodySize >= %d", value))
        }
        if let value = criteria.request.requestSize.byteCountRange.upperBound {
            predicates.append(NSPredicate(format: "requestBodySize <= %d", value))
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
        switch criteria.networking.requestState {
        case .any:
            break
        case .pending:
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.pending.rawValue))
        case .success:
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.success.rawValue))
        case .failure:
            predicates.append(NSPredicate(format: "requestState == %d", NetworkTaskEntity.State.failure.rawValue))
        }
    }

    if criteria.custom.isEnabled {
        let filterPredicates = criteria.custom.filters
            .filter { !$0.value.isEmpty && $0.isEnabled }
            .map { $0.makePredicate() }
        if !filterPredicates.isEmpty {
            switch criteria.custom.logicalOperator {
            case .and:
                predicates.append(contentsOf: filterPredicates)
            case .or:
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: filterPredicates))
            }
        }
    }
    return predicates
}
