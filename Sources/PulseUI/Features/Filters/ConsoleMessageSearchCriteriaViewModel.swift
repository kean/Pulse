// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleMessageSearchCriteriaViewModel: ObservableObject {
    @Published var criteria: ConsoleMessageSearchCriteria = .default
    private(set) var defaultCriteria: ConsoleMessageSearchCriteria = .default
    @Published var filters: [ConsoleSearchFilter] = []

    @Published private(set) var allLabels: [String] = []
    private var allLabelsSet: Set<String> = []
    private let labels: ManagedObjectsObserver<LoggerLabelEntity>

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        labels = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \LoggerLabelEntity.name, ascending: true))

        labels.$objects.sink { [weak self] in
            self?.displayLabels($0.map(\.name))
        }.store(in: &cancellables)

        resetFilters()

        $criteria.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    var isDefaultSearchCriteria: Bool {
        criteria == defaultCriteria && isDefaultFilters
    }

    var isDefaultFilters: Bool {
        filters.count == 1 && filters[0].value.isEmpty
    }

    func resetAll() {
        criteria = defaultCriteria
        resetFilters()
        isButtonResetEnabled = false
    }

    // MARK: Managing Custom Filters

    func resetFilters() {
        filters = [.default]
        for filter in filters {
            subscribe(to: filter)
        }
    }

    func addFilter() {
        guard !filters.isEmpty else {
            return resetFilters()
        }
        let filter = ConsoleSearchFilter.default
        filters.append(filter)
        subscribe(to: filter)
    }

    private func subscribe(to filter: ConsoleSearchFilter) {
        filter.objectWillChange.sink { [weak self] in
            guard let self = self else { return }
            self.objectWillChange.send()
            self.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    func removeFilter(_ filter: ConsoleSearchFilter) {
        if let index = filters.firstIndex(where: { $0 === filter }) {
            filters.remove(at: index)
        }
        if filters.isEmpty {
            resetFilters()
        }
    }

    // MARK: Managing Labels

    func displayLabels(_ labels: [String]) {
        allLabelsSet = Set(labels)
        allLabels = labels
    }

    // MARK: Helpers

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
}
