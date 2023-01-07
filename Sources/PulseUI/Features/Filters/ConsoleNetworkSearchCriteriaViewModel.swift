// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine
import SwiftUI

#if os(iOS) || os(macOS) || os(tvOS)

final class ConsoleNetworkSearchCriteriaViewModel: ObservableObject {
    @Binding var dates: ConsoleMessageSearchCriteria.DatesFilter
    @Published var criteria: NetworkSearchCriteria = .default
    private(set) var defaultCriteria: NetworkSearchCriteria = .default
    @Published var filters: [NetworkSearchFilter] = []

    @Published private(set) var allDomains: [String] = []
    private let domains: ManagedObjectsObserver<NetworkDomainEntity>

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    var isDefaultSearchCriteria: Bool {
        criteria == defaultCriteria && (filters.count == 0 || (filters.count == 1 && filters == NetworkSearchFilter.defaultFilters))
    }

    var isDefaultDatesFilter: Bool {
        var defaultFilter = ConsoleMessageSearchCriteria.DatesFilter.default
        defaultFilter.isCurrentSessionOnly = isCurrentStore
        return dates == defaultFilter
    }

    private var cancellables: [AnyCancellable] = []
    private let isCurrentStore: Bool

    init(store: LoggerStore, dates: Binding<ConsoleMessageSearchCriteria.DatesFilter>) {
        _dates = dates
        domains = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \NetworkDomainEntity.count, ascending: false))
        isCurrentStore = store === LoggerStore.shared // TODO: refactor

        domains.$objects.sink { [weak self] in
            self?.allDomains = $0.map(\.value)
        }.store(in: &cancellables)

        resetFilters()

        $filters.dropFirst().sink { [weak self] _ in
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)

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

    private func enableResetIfNeeded() {
        if isButtonResetEnabled != true {
            isButtonResetEnabled = true
        }
    }

    // MARK: Managing Custom Filters

    func resetFilters() {
        filters = NetworkSearchFilter.defaultFilters
        for filter in filters {
            subscribe(to: filter)
        }
    }

    func addFilter() {
        let filter = NetworkSearchFilter(id: UUID(), field: .url, match: .equal, value: "")
        filters.append(filter)

        subscribe(to: filter)
    }

    private func subscribe(to filter: NetworkSearchFilter) {
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

    func removeFilter(_ filter: NetworkSearchFilter) {
        if let index = filters.firstIndex(of: filter) {
            filters.remove(at: index)
        }
    }

    var programmaticFilters: [NetworkSearchFilter]? {
        let programmaticFilters = filters.filter { $0.isProgrammatic && $0.isReady }
        guard !programmaticFilters.isEmpty && criteria.isFiltersEnabled else {
            return nil
        }
        return programmaticFilters
    }

    // MARK: Bindings

    var bindingStartDate: Binding<Date> {
        Binding(get: {
            self.dates.startDate ?? Date().addingTimeInterval(-3600)
        }, set: { newValue in
            self.dates.isStartDateEnabled = true
            self.dates.startDate = newValue
        })
    }

    var bindingEndDate: Binding<Date> {
        Binding(get: {
            self.dates.endDate ?? Date()
        }, set: { newValue in
            self.dates.isEndDateEnabled = true
            self.dates.endDate = newValue
        })
    }

    func binding(forDomain domain: String) -> Binding<Bool> {
        Binding(get: {
            self.criteria.host.values.contains(domain)
        }, set: { newValue in
            if self.criteria.host.values.remove(domain) == nil {
                self.criteria.host.values.insert(domain)
            }
        })
    }
}

#endif
