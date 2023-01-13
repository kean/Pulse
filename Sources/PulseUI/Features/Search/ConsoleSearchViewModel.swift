// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleSearchViewModel: ObservableObject {
    var isButtonResetEnabled: Bool { !isCriteriaDefault }

    @Published var criteria = ConsoleSearchCriteria()
    @Published var mode: ConsoleViewModel.Mode = .messages // warning: not source of truth

    @Published private(set) var labels: [String] = []
    @Published private(set) var domains: [String] = []

    private(set) var labelsCountedSet = NSCountedSet()
    private(set) var domainsCountedSet = NSCountedSet()

    private(set) var defaultCriteria = ConsoleSearchCriteria()

    private let store: LoggerStore
    private let entities: CurrentValueSubject<[NSManagedObject], Never>
    private var isActive = false
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, entities: CurrentValueSubject<[NSManagedObject], Never>) {
        self.store = store
        self.entities = entities

        if store.isArchive {
            self.criteria.shared.dates.startDate = nil
            self.criteria.shared.dates.endDate = nil
        }
        self.defaultCriteria = criteria

        entities.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.reloadCounters()
        }.store(in: &cancellables)
    }

    // MARK: Appearance

    func onAppear() {
        isActive = true
        reloadCounters()
    }

    func onDisappear() {
        isActive = false
    }

    // MARK: Helpers

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

    private func reloadCounters() {
        guard isActive else { return }

        switch mode {
        case .messages:
            guard let messages = entities.value as? [LoggerMessageEntity] else {
                return assertionFailure()
            }
            labelsCountedSet = NSCountedSet(array: messages.map(\.label.name))
            labels = (labelsCountedSet.allObjects as! [String]).sorted()
        case .network:
            guard let tasks = entities.value as? [NetworkTaskEntity] else {
                return assertionFailure()
            }
            domainsCountedSet = NSCountedSet(array: tasks.compactMap { $0.host?.value })
            domains = (domainsCountedSet.allObjects as! [String]).sorted(by: { lhs, rhs in
                domainsCountedSet.count(for: lhs) > domainsCountedSet.count(for: rhs)
            })
        }
    }

    // MARK: Binding (LogLevels)

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

    var isAllLogLevelsEnabled: Bool {
        get {
            criteria.messages.logLevels.levels.count == LoggerStore.Level.allCases.count
        }
        set {
            if newValue {
                criteria.messages.logLevels.levels = Set(LoggerStore.Level.allCases)
            } else {
                criteria.messages.logLevels.levels = []
            }
        }
    }

    // MARK: Binding (Labels)

    var selectedLabels: Set<String> {
        get {
            if let focused = criteria.messages.labels.focused {
                return [focused]
            } else {
                return Set(labels).subtracting(criteria.messages.labels.hidden)
            }
        }
        set {
            criteria.messages.labels.focused = nil
            criteria.messages.labels.hidden = []
            switch newValue.count {
            case 1:
                criteria.messages.labels.focused = newValue.first!
            default:
                criteria.messages.labels.hidden = Set(labels).subtracting(newValue)
            }
        }
    }

    // MARK: Custom Filters

    var programmaticFilters: [ConsoleCustomNetworkFilter]? {
        let programmaticFilters = criteria.network.custom.filters.filter { $0.isProgrammatic && !$0.value.isEmpty }
        guard !programmaticFilters.isEmpty && criteria.network.custom.isEnabled else {
            return nil
        }
        return programmaticFilters
    }

    // MARK: Bindings (Hosts)

    var selectedHost: Set<String> {
        get {
            Set(domains).subtracting(criteria.network.host.ignoredHosts)
        }
        set {
            criteria.network.host.ignoredHosts = Set(domains).subtracting(newValue)
        }
    }
}
