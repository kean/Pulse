// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

#warning("TODO: use the new picker for labels and stuff")
#warning("TODO: rework how labels and domains aare loaded - use Published?")
#warning("TODO: are we display lavels from all messages? is this ok?")
#warning("TODO: display number of items next to each one if possible")
#warning("TODO: also add short view with a limit how many to display + use on all platforms including macOS")
final class ConsoleSearchViewModel: ObservableObject {
    var isButtonResetEnabled: Bool { !isCriteriaDefault }

    @Published var criteria = ConsoleSearchCriteria()
    @Published var mode: ConsoleViewModel.Mode = .messages

    @Published private(set) var labels: [String] = []
    @Published private(set) var domains: [String] = []

    private let labelsObserver: ManagedObjectsObserver<LoggerLabelEntity>
    private let domainsObserver: ManagedObjectsObserver<NetworkDomainEntity>

    private(set) var defaultCriteria = ConsoleSearchCriteria()
    private let store: LoggerStore
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore) {
        self.store = store

        self.labelsObserver = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \LoggerLabelEntity.name, ascending: true))

        self.domainsObserver = ManagedObjectsObserver(context: store.viewContext, sortDescriptior: NSSortDescriptor(keyPath: \NetworkDomainEntity.count, ascending: false))

        if store.isArchive {
            self.criteria.shared.dates.startDate = nil
            self.criteria.shared.dates.endDate = nil
        }
        self.defaultCriteria = criteria

        labelsObserver.$objects.sink { [weak self] in
            #warning("TEMP")
            self?.labels = ["TestA", "TestB"] + $0.map(\.name)
        }.store(in: &cancellables)

        domainsObserver.$objects.sink { [weak self] in
            self?.domains = $0.map(\.value)
        }.store(in: &cancellables)
    }

    var isCriteriaDefault: Bool {
        guard criteria.shared == defaultCriteria.shared else { return false }
        switch mode {
        case .messages: return criteria.messages == defaultCriteria.messages
        case .network: return criteria.network == defaultCriteria.network
        }
    }

    func resetAll() {
        criteria = defaultCriteria
    }

    func removeAllPins() {
        store.pins.removeAllPins()

#if os(iOS)
        runHapticFeedback(.success)
        ToastView {
            HStack {
                Image(systemName: "trash")
                Text("All pins removed")
            }
        }.show()
#endif
    }

    // MARK: Binding (ConsoleFilters.LogLevel)

    func binding(forLevel level: LoggerStore.Level) -> Binding<Bool> {
        Binding(get: {
            self.criteria.messages.logLevels.levels.contains(level)
        }, set: { isOn in
            if isOn {
                self.criteria.messages.logLevels.levels.insert(level)
            } else {
                self.criteria.messages.logLevels.levels.remove(level)
            }
        })
    }

    /// Returns binding for toggling all log levels.
    var bindingForTogglingAllLevels: Binding<Bool> {
        Binding(get: {
            self.criteria.messages.logLevels.levels.count == LoggerStore.Level.allCases.count
        }, set: { isOn in
            if isOn {
                self.criteria.messages.logLevels.levels = Set(LoggerStore.Level.allCases)
            } else {
                self.criteria.messages.logLevels.levels = Set()
            }
        })
    }

    // MARK: Binding (ConsoleFilters.Labels)

    var selectedLabels: Set<String> {
        get {
            if let focused = self.criteria.messages.labels.focused {
                return [focused]
            } else {
                return Set(self.labels).subtracting(self.criteria.messages.labels.hidden)
            }
        }
        set {
            self.criteria.messages.labels.focused = nil
            self.criteria.messages.labels.hidden = []
            switch newValue.count {
            case 1:
                self.criteria.messages.labels.focused = newValue.first!
            default:
                self.criteria.messages.labels.hidden = Set(self.labels).subtracting(newValue)
            }
        }
    }

    // MARK: Custom Filters

    func remove(_ filter: ConsoleCustomMessageFilter) {
        if let index = criteria.messages.custom.filters.firstIndex(where: { $0.id == filter.id }) {
            criteria.messages.custom.filters.remove(at: index)
        }
    }

    func remove(_ filter: ConsoleCustomNetworkFilter) {
        if let index = criteria.network.custom.filters.firstIndex(where: { $0.id == filter.id }) {
            criteria.network.custom.filters.remove(at: index)
        }
    }

    var programmaticFilters: [ConsoleCustomNetworkFilter]? {
        let programmaticFilters = criteria.network.custom.filters.filter { $0.isProgrammatic && !$0.value.isEmpty }
        guard !programmaticFilters.isEmpty && criteria.network.custom.isEnabled else {
            return nil
        }
        return programmaticFilters
    }

    // MARK: Bindings

    func binding(forDomain domain: String) -> Binding<Bool> {
        Binding(get: {
            !self.criteria.network.host.ignoredHosts.contains(domain)
        }, set: { newValue in
            if self.criteria.network.host.ignoredHosts.remove(domain) == nil {
                self.criteria.network.host.ignoredHosts.insert(domain)
            }
        })
    }
}
