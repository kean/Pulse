// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
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

    // The actual filters had to be moved to the viewmodel
    static let defaultFilters = [ConsoleSearchFilter(id: UUID(), field: .message, match: .contains, value: "")]

    var isDefault: Bool {
        field == .message && match == .contains && value == ""
    }

    init(id: UUID, field: Field, match: Match, value: String) {
        self.id = id
        self.field = field
        self.match = match
        self.value = value
    }

    static func == (lhs: ConsoleSearchFilter, rhs: ConsoleSearchFilter) -> Bool {
        lhs.id == rhs.id &&
        lhs.field == rhs.field &&
        lhs.match == rhs.match &&
        lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(field)
        hasher.combine(match)
        hasher.combine(value)
    }

    var isReady: Bool {
        !value.isEmpty
    }

    enum Field {
        case level
        case label
        case message
        case metadata
        case file

        var localizedTitle: String {
            switch self {
            case .level: return "Level"
            case .label: return "Label"
            case .message: return "Message"
            case .metadata: return "Metadata"
            case .file: return "File"
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
        case .label: return "label.name"
        case .message: return "text"
        case .metadata: return "rawMetadata"
        case .file: return "file"
        }
    }
}

extension ConsoleSearchCriteria {

    static func update(
        request: NSFetchRequest<LoggerMessageEntity>,
        filterTerm: String,
        criteria: ConsoleSearchCriteria,
        filters: [ConsoleSearchFilter],
        sessionId: UUID?,
        isOnlyErrors: Bool,
        isOnlyNetwork: Bool
    ) {
        var predicates = [NSPredicate]()

        if isOnlyNetwork {
            predicates.append(NSPredicate(format: "request != nil"))
        }

        if criteria.dates.isCurrentSessionOnly, let sessionId = sessionId {
            predicates.append(NSPredicate(format: "session == %@", sessionId as NSUUID))
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
                predicates.append(NSPredicate(format: "label.name == %@", focusedLabel))
            } else if !criteria.labels.hidden.isEmpty {
                predicates.append(NSPredicate(format: "NOT label.name IN %@", Array(criteria.labels.hidden)))
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
