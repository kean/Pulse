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

    @Published private(set) var allDomains: [String] = []
    private let domains: ManagedObjectsObserver<NetworkDomainEntity>

    @Published private(set) var isButtonResetEnabled = false

    let dataNeedsReload = PassthroughSubject<Void, Never>()

    var isDefaultSearchCriteria: Bool {
        criteria == defaultCriteria
    }

    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        domains = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \NetworkDomainEntity.count, ascending: false))

        domains.$objects.sink { [weak  self] in
            self?.allDomains = $0.map(\.value)
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

    func removeFilter(_ filter: ConsoleCustomNetworkFilter) {
        if let index = criteria.customNetworkFilters.filters.firstIndex(where: { $0.id == filter.id }) {
            criteria.customNetworkFilters.filters.remove(at: index)
        }
        if criteria.customNetworkFilters.filters.isEmpty {
            criteria.customNetworkFilters = .default
        }
    }

#warning("TODO: move to ConsoleFilters+extensions")
    var programmaticFilters: [ConsoleCustomNetworkFilter]? {
        let programmaticFilters = criteria.customNetworkFilters.filters.filter { $0.isProgrammatic && !$0.value.isEmpty }
        guard !programmaticFilters.isEmpty && criteria.customNetworkFilters.isEnabled else {
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
