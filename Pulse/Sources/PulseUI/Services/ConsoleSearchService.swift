// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData

struct ConsoleSearchCriteria: Hashable {
    var logLevels = Set(LoggerStore.Level.allCases).subtracting([LoggerStore.Level.trace])

    #if os(iOS)
    var isCurrentSessionOnly = true
    #else
    var isCurrentSessionOnly = false
    #endif

    var startDate: Date?
    var endDate: Date?
    var hiddenLabels: Set<String> = []
    var focusedLabel: String?

    #if os(watchOS) || os(tvOS)
    var onlyPins = false
    var onlyNetwork = false
    #endif

    static let `default` = ConsoleSearchCriteria()

    var isDefault: Bool {
        self == ConsoleSearchCriteria.default
    }
}

private let isNetworkMessagePredicate = NSPredicate(format: "request != nil")

extension ConsoleSearchCriteria {
    
    static func update(request: NSFetchRequest<LoggerMessageEntity>, contentType: ConsoleContentType, filterTerm: String, criteria: ConsoleSearchCriteria, sessionId: String?) {
        var predicates = [NSPredicate]()

        // TODO: Optimize performance, network requests should not require so many queries
        switch contentType {
        case .all:
            break
        case .network:
            predicates.append(isNetworkMessagePredicate)
        case .pins:
            break
        }

        // TODO: refactor
        #if os(watchOS) || os(tvOS)
        if criteria.onlyNetwork {
            predicates.append(isNetworkMessagePredicate)
        }
        #endif

        if criteria.isCurrentSessionOnly, let sessionId = sessionId, !sessionId.isEmpty {
            predicates.append(NSPredicate(format: "session == %@", sessionId))
        }

        if let startDate = criteria.startDate {
            predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
        }
        if let endDate = criteria.endDate {
            predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
        }

        if criteria.logLevels.count != LoggerStore.Level.allCases.count {
            predicates.append(NSPredicate(format: "level IN %@", Array(criteria.logLevels.map { $0.rawValue })))
        }

        if let focusedLabel = criteria.focusedLabel {
            predicates.append(NSPredicate(format: "label == %@", focusedLabel))
        } else if !criteria.hiddenLabels.isEmpty {
            predicates.append(NSPredicate(format: "NOT label IN %@", Array(criteria.hiddenLabels)))
        }

        if filterTerm.count > 1 {
            predicates.append(NSPredicate(format: "text CONTAINS[cd] %@", filterTerm))
        }
        
        request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
