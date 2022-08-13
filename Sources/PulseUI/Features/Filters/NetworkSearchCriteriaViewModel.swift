// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine
import SwiftUI

#if os(iOS) || os(macOS) || os(tvOS)

final class NetworkSearchCriteriaViewModel: ObservableObject {
    @Published var criteria: NetworkSearchCriteria = .default
    private(set) var defaultCriteria: NetworkSearchCriteria = .default
    @Published var filters: [NetworkSearchFilter] = []

    @Published private(set) var allDomains: [String] = []
    private var allDomainsSet: Set<String> = []

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    private var cancellables: [AnyCancellable] = []

    var isDefaultSearchCriteria: Bool {
        criteria == defaultCriteria && (filters.count == 0 || (filters.count == 1 && filters == NetworkSearchFilter.defaultFilters))
    }

    init(isDefaultStore: Bool = true) {
        if !isDefaultStore {
            criteria.dates.isCurrentSessionOnly = false
            defaultCriteria.dates.isCurrentSessionOnly = false
        }
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

    // MARK: Managing Domains

    func setInitialDomains(_ domains: Set<String>) {
        allDomainsSet = domains
        allDomains = allDomainsSet.sorted()
    }

    #warning("TODO: rewrite this")
    func didInsertEntity(_ entity: NetworkTaskEntity) {
        var domains = allDomainsSet
        if let host = entity.host?.value {
            domains.insert(host)
        }
        if domains.count > allDomains.count {
            allDomainsSet = domains
            allDomains = allDomainsSet.sorted()
        }
    }

    // MARK: Bindings

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
