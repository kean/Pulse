// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData
import Combine

final class NetworkSearchCriteriaViewModel: ObservableObject {
    @Published var criteria: NetworkSearchCriteria = .default
    @Published var filters: [NetworkSearchFilter] = []

    @Published private(set) var allDomains: [String] = []
    private var allDomainsSet: Set<String> = []

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    private var cancellables: [AnyCancellable] = []

    init() {
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
        criteria = .default
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
        let filter = NetworkSearchFilter(id: UUID(), field: .url, match: .equal, value: "", isEnabled: true)
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

    // MARK: Managing Domains

    func setInitialDomains(_ domains: Set<String>) {
        allDomainsSet = domains
        allDomains = allDomainsSet.sorted()
    }

    func didInsertEntity(_ entity: LoggerNetworkRequestEntity) {
        var domains = allDomainsSet
        if let host = entity.host {
            domains.insert(host)
        }
        if domains.count > allDomains.count {
            allDomainsSet = domains
            allDomains = allDomainsSet.sorted()
        }
    }
}
