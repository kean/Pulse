// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
final class ConsoleSearchCriteriaViewModel: ObservableObject {
    @Published var criteria: ConsoleSearchCriteria = .default
    private(set) var defaultCriteria: ConsoleSearchCriteria = .default
    @Published var filters: [ConsoleSearchFilter] = []
    
    @Published private(set) var allLabels: [String] = []
    private var allLabelsSet: Set<String> = []
    
    @Published private(set) var isButtonResetEnabled = false
    
    let dataNeedsReload = PassthroughSubject<Void, Never>()
    
    private var cancellables: [AnyCancellable] = []

    init(isDefaultStore: Bool = true) {
        if !isDefaultStore {
            criteria.dates.isCurrentSessionOnly = false
            defaultCriteria.dates.isCurrentSessionOnly = false
        }
        
        resetFilters()
        
        $criteria.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    func resetAll() {
        criteria = defaultCriteria
        resetFilters()
        isButtonResetEnabled = false
    }
    
    // MARK: Managing Custom Filters
    
    func resetFilters() {
        filters = ConsoleSearchFilter.defaultFilters
        for filter in filters {
            subscribe(to: filter) 
        }
    }
    
    func addFilter() {
        let filter = ConsoleSearchFilter(id: UUID(), field: .message, match: .contains, value: "", isEnabled: true)
        filters.append(filter)
        
        subscribe(to: filter)
    }
    
    private func subscribe(to filter: ConsoleSearchFilter) {
        filter.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
            self?.isButtonResetEnabled = true
        }.store(in: &cancellables)
        
        filter.objectWillChange.sink { [weak self] in
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }
    
    func removeFilter(_ filter: ConsoleSearchFilter) {
        if let index = filters.firstIndex(of: filter) {
            filters.remove(at: index)
        }
    }
    
    // MARK: Managing Labels
    
    func setInitialLabels(_ labels: Set<String>) {
        allLabelsSet = labels
        allLabels = allLabelsSet.sorted()
    }
    
    func didInsertEntity(_ entity: LoggerMessageEntity) {
        var labels = allLabelsSet
        labels.insert(entity.label)
        if labels.count > allLabels.count {
            allLabelsSet = labels
            allLabels = allLabelsSet.sorted()
        }
    }
    
    // MARK: Helpers
    
    /// Returns binding to toggling the given toggle level.
    func binding(forLevel level: LoggerStore.Level) -> Binding<Bool> {
        Binding(get: {
            self.criteria.logLevels.levels.contains(level)
        }, set: { isOn in
            if isOn {
                self.criteria.logLevels.levels.insert(level)
            } else {
                self.criteria.logLevels.levels.remove(level)
            }
        })
    }
    
    /// Returns binding for toggling all log levels.
    var bindingForTogglingAllLevels: Binding<Bool> {
        Binding(get: {
            self.criteria.logLevels.levels.count == LoggerStore.Level.allCases.count
        }, set: { isOn in
            if isOn {
                self.criteria.logLevels.levels = Set(LoggerStore.Level.allCases)
            } else {
                self.criteria.logLevels.levels = Set()
            }
        })
    }
    
    func binding(forLabel label: String) -> Binding<Bool> {
        Binding(get: {
            !self.criteria.labels.hidden.contains(label)
        }, set: { isOn in
            self.criteria.labels.focused = nil
            if isOn {
                self.criteria.labels.hidden.remove(label)
            } else {
                self.criteria.labels.hidden.insert(label)
            }
        })
    }
    
    var bindingForTogglingAllLabels: Binding<Bool> {
        Binding(get: {
            self.criteria.labels.hidden.isEmpty
        }, set: { isOn in
            self.criteria.labels.focused = nil
            if isOn {
                self.criteria.labels.hidden = []
            } else {
                self.criteria.labels.hidden = Set(self.allLabels)
            }
        })
    }

    var bindingStartDate: Binding<Date> {
        Binding(get: {
            self.criteria.dates.startDate ?? Date().addingTimeInterval(-3600)
        }, set: { newValue in
            self.criteria.dates.isStartDateEnabled = true
            self.criteria.dates.startDate = newValue
        })
    }
    
    var bindingEndDate: Binding<Date> {
        Binding(get: {
            self.criteria.dates.endDate ?? Date()
        }, set: { newValue in
            self.criteria.dates.isEndDateEnabled = true
            self.criteria.dates.endDate = newValue
        })
    }
}
