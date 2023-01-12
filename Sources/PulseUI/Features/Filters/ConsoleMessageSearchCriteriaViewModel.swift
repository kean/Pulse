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

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
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
}
