// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import Combine
import SwiftUI

final class ConsoleNetworkSearchCriteriaViewModel: ObservableObject {
    @Published var criteria: ConsoleNetworkSearchCriteria = .default
    private(set) var defaultCriteria: ConsoleNetworkSearchCriteria = .default
    @Published var filters: [NetworkSearchFilter] = []

    @Published private(set) var allDomains: [String] = []
    private let domains: ManagedObjectsObserver<NetworkDomainEntity>

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    var isDefaultSearchCriteria: Bool {
        criteria == defaultCriteria && isDefaultFilters
    }

    var isDefaultFilters: Bool {
        filters.count == 1 && filters[0].value.isEmpty
    }

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        domains = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \NetworkDomainEntity.count, ascending: false))

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

    func mock(domains: [String]) {
        self.allDomains = domains
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
        let filter = NetworkSearchFilter.default
        filters.append(filter)
        subscribe(to: filter)
    }

    private func subscribe(to filter: NetworkSearchFilter) {
        filter.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
            self?.isButtonResetEnabled = true
            DispatchQueue.main.async { // important!
                self?.dataNeedsReload.send()
            }
        }.store(in: &cancellables)
    }

    func removeFilter(_ filter: NetworkSearchFilter) {
        if let index = filters.firstIndex(where: { $0 === filter }) {
            filters.remove(at: index)
        }
        if filters.isEmpty {
            resetFilters()
        }
    }

    var programmaticFilters: [NetworkSearchFilter]? {
        let programmaticFilters = filters.filter { $0.isProgrammatic && !$0.value.isEmpty }
        guard !programmaticFilters.isEmpty && criteria.isFiltersEnabled else {
            return nil
        }
        return programmaticFilters
    }

    // MARK: Bindings

    func binding(forDomain domain: String) -> Binding<Bool> {
        Binding(get: {
            !self.criteria.host.ignoredHosts.contains(domain)
        }, set: { newValue in
            if self.criteria.host.ignoredHosts.remove(domain) == nil {
                self.criteria.host.ignoredHosts.insert(domain)
            }
        })
    }
}
