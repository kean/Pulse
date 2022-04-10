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
    @Published var filters: [ConsoleSearchFilter] = []
    
    @Published private(set) var allLabels: [String] = []
    private var allLabelsSet: Set<String> = []
    
    @Published private(set) var isButtonResetEnabled = false
    
    let dataNeedsReload = PassthroughSubject<Void, Never>()
    
    private var cancellables: [AnyCancellable] = []
    
    init() {
        resetFilters()
        
        $criteria.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    func resetAll() {
        criteria = .default
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
}
