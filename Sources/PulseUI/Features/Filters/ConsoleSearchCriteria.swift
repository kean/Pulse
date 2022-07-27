// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData
import SwiftUI

struct ConsoleSearchCriteria: Hashable {
    var isFiltersEnabled = true

    var logLevels = LogLevelsFilter.default
    var dates = DatesFilter.default
    var labels = LabelsFilter.default

    struct LogLevelsFilter: Hashable {
        var isEnabled = true
        var levels = LogLevelsFilter.defaultLogLevels

        static let defaultLogLevels = Set(LoggerStore.Level.allCases).subtracting([LoggerStore.Level.trace])

        static let `default` = LogLevelsFilter()
    }

    struct DatesFilter: Hashable {
        var isEnabled = true

        #if os(iOS) || os(watchOS) || os(tvOS)
        var isCurrentSessionOnly = true
        #else
        var isCurrentSessionOnly = false
        #endif

        var isStartDateEnabled = false
        var startDate: Date?
        var isEndDateEnabled = false
        var endDate: Date?

        static let `default` = DatesFilter()

        static var today: DatesFilter {
            make(startDate: Calendar.current.startOfDay(for: Date()), endDate: nil)
        }

        static var recent: DatesFilter {
            make(startDate: Date().addingTimeInterval(-1800), endDate: nil)
        }

        static func make(startDate: Date, endDate: Date? = nil) -> DatesFilter {
            DatesFilter(isEnabled: true, isCurrentSessionOnly: false, isStartDateEnabled: true, startDate: startDate, isEndDateEnabled: endDate != nil, endDate: endDate)
        }
    }

    struct LabelsFilter: Hashable {
        var isEnabled = true
        var hidden: Set<String> = []
        var focused: String?

        static let `default` = LabelsFilter()
    }

#if os(watchOS)
    var onlyPins = false
    var onlyNetwork = false
#endif

    static let `default` = ConsoleSearchCriteria()

    var isDefault: Bool {
        self == ConsoleSearchCriteria.default
    }
}

final class ConsoleSearchFilter: ObservableObject, Hashable, Identifiable {
    let id: UUID
    @Published var field: Field
    @Published var match: Match
    @Published var value: String
    @Published var isEnabled: Bool

    // The actual filters had to be moved to the viewmodel
    static var defaultFilters: [ConsoleSearchFilter] {
        [ConsoleSearchFilter(id: UUID(), field: .message, match: .contains, value: "", isEnabled: true)]
    }

    var isDefault: Bool {
        field == .message && match == .contains && value == "" && isEnabled
    }

    init(id: UUID, field: Field, match: Match, value: String, isEnabled: Bool) {
        self.id = id
        self.field = field
        self.match = match
        self.value = value
        self.isEnabled = isEnabled
    }

    static func == (lhs: ConsoleSearchFilter, rhs: ConsoleSearchFilter) -> Bool {
        lhs.id == rhs.id &&
        lhs.field == rhs.field &&
        lhs.match == rhs.match &&
        lhs.value == rhs.value &&
        lhs.isEnabled == rhs.isEnabled
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(field)
        hasher.combine(match)
        hasher.combine(value)
        hasher.combine(isEnabled)
    }

    var isReady: Bool {
        isEnabled && !value.isEmpty
    }

    enum Field {
        case level
        case label
        case message
        case metadata
        case file
        case function
        case line

        var localizedTitle: String {
            switch self {
            case .level: return "Level"
            case .label: return "Label"
            case .message: return "Message"
            case .metadata: return "Metadata"
            case .file: return "File"
            case .function: return "Function"
            case .line: return "Line"
            }
        }
    }

    enum Match {
        case equal // LIKE[c]
        case notEqual
        case contains
        case notContains
        case regex
        case beginsWith

        var localizedTitle: String {
            switch self {
            case .equal: return "Equal"
            case .notEqual: return "Not Equal"
            case .contains: return "Contains"
            case .notContains: return "Not Contains"
            case .regex: return "Regex"
            case .beginsWith: return "Begins With"
            }
        }
    }

    func makePredicate() -> NSPredicate? {
        if field == .metadata {
            return makePredicateForMetadata()
        }
        guard let key = self.key else {
            return nil
        }
        switch match {
        case .equal: return NSPredicate(format: "\(key) LIKE[c] %@", value)
        case .notEqual: return NSPredicate(format: "NOT (\(key) LIKE[c] %@)", value)
        case .contains: return NSPredicate(format: "\(key) CONTAINS[c] %@", value)
        case .notContains: return NSPredicate(format: "NOT (\(key) CONTAINS[c] %@)", value)
        case .beginsWith: return NSPredicate(format: "\(key) BEGINSWITH[c] %@", value)
        case .regex: return NSPredicate(format: "\(key) MATCHES %@", value)
        }
    }

    private func makePredicateForMetadata() -> NSPredicate {
        switch match {
        case .equal: return NSPredicate(format: "SUBQUERY(metadata, $entry, $entry.key LIKE[c] %@ OR $entry.value LIKE[c] %@).@count > 0", value, value)
        case .notEqual: return NSPredicate(format: "SUBQUERY(metadata, $entry, $entry.key LIKE[c] %@ OR $entry.value LIKE[c] %@).@count == 0", value, value)
        case .contains: return NSPredicate(format: "SUBQUERY(metadata, $entry, $entry.key CONTAINS[c] %@ OR $entry.value CONTAINS[c] %@).@count > 0", value, value)
        case .notContains: return NSPredicate(format: "SUBQUERY(metadata, $entry, $entry.key CONTAINS[c] %@ OR $entry.value CONTAINS[c] %@).@count == 0", value, value)
        case .beginsWith: return NSPredicate(format: "SUBQUERY(metadata, $entry, $entry.key BEGINSWITH[c] %@ OR $entry.value CONTAINS[c] %@).@count > 0", value, value)
        case .regex: return NSPredicate(format: "SUBQUERY(metadata, $entry, $entry.key MATCHES[c] %@ OR $entry.value MATCHES[c] %@).@count > 0", value, value)
        }
    }

    func matches(string: String) -> Bool {
        switch match {
        case .equal: return string.caseInsensitiveCompare(value) == .orderedSame
        case .notEqual: return string.caseInsensitiveCompare(value) != .orderedSame
        case .contains: return string.firstRange(of: value, options: [.caseInsensitive]) != nil
        case .notContains: return string.firstRange(of: value, options: [.caseInsensitive]) == nil
        case .regex: return string.firstRange(of: value, options: [.caseInsensitive, .regularExpression]) != nil
        case .beginsWith: return string.firstRange(of: value, options: [.caseInsensitive, .anchored]) != nil
        }
    }

    private var key: String? {
        switch field {
        case .level: return "level"
        case .label: return "label"
        case .message: return "text"
        case .metadata: return nil
        case .file: return "file"
        case .function: return "function"
        case .line: return "line"
        }
    }
}

extension ConsoleSearchCriteria {

    static func update(
        request: NSFetchRequest<LoggerMessageEntity>,
        filterTerm: String,
        criteria: ConsoleSearchCriteria,
        filters: [ConsoleSearchFilter],
        sessionId: String?,
        isOnlyErrors: Bool
    ) {
        var predicates = [NSPredicate]()

#if os(watchOS)
        if criteria.onlyNetwork {
            predicates.append(NSPredicate(format: "request != nil"))
        }
#endif

        if criteria.dates.isCurrentSessionOnly, let sessionId = sessionId, !sessionId.isEmpty {
            predicates.append(NSPredicate(format: "session == %@", sessionId))
        }

        if criteria.dates.isEnabled {
            if criteria.dates.isStartDateEnabled, let startDate = criteria.dates.startDate {
                predicates.append(NSPredicate(format: "createdAt >= %@", startDate as NSDate))
            }
            if criteria.dates.isEndDateEnabled, let endDate = criteria.dates.endDate {
                predicates.append(NSPredicate(format: "createdAt <= %@", endDate as NSDate))
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
                predicates.append(NSPredicate(format: "label == %@", focusedLabel))
            } else if !criteria.labels.hidden.isEmpty {
                predicates.append(NSPredicate(format: "NOT label IN %@", Array(criteria.labels.hidden)))
            }
        }

        if filterTerm.count > 1 {
            predicates.append(NSPredicate(format: "text CONTAINS[cd] %@", filterTerm))
        }

        if criteria.isFiltersEnabled {
            for filter in filters where filter.isReady {
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
