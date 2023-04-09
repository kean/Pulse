// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleSearchCriteriaViewModel: ObservableObject {
    var isButtonResetEnabled: Bool { !isCriteriaDefault }

    @Published var mode: ConsoleMode = .all
    @Published var options = ConsolePredicateOptions()

    var criteria: ConsoleSearchCriteria {
        get { options.criteria }
        set { options.criteria = newValue }
    }

    let defaultCriteria: ConsoleSearchCriteria

    @Published private(set) var labels: [String] = []
    @Published private(set) var domains: [String] = []

    private(set) var labelsCountedSet = NSCountedSet()
    private(set) var domainsCountedSet = NSCountedSet()

    private let index: LoggerStoreIndex
    private var isScreenVisible = false
    private var entities: [NSManagedObject] = []
    private var cancellables: [AnyCancellable] = []

    /// Initializes the view model with the initial criteria.
    ///
    /// - Parameters:
    ///   - criteria: The initial search criteria.
    ///   - index: The store index.
    init(criteria: ConsoleSearchCriteria, index: LoggerStoreIndex) {
        self.index = index
        self.defaultCriteria = criteria
        self.options.criteria = criteria
    }

    func bind(_ entities: some Publisher<[NSManagedObject], Never>) {
        entities.sink { [weak self] in
            guard let self else { return }
            self.entities = $0
            if self.isScreenVisible {
                self.reloadCounters()
            }
        }.store(in: &cancellables)
    }

    // MARK: Appearance

    func onAppear() {
        isScreenVisible = true
        reloadCounters()
    }

    func onDisappear() {
        isScreenVisible = false
    }

    // MARK: Helpers

    var isCriteriaDefault: Bool {
        guard criteria.shared == defaultCriteria.shared else { return false }
        if mode == .network {
            return criteria.network == defaultCriteria.network
        } else {
            return criteria.messages == defaultCriteria.messages
        }
    }

    func select(sessions: Set<UUID>) {
        var options = self.options
#warning("this is no longer needed")
        options.criteria.shared.dates.startDate = nil
        options.criteria.shared.dates.endDate = nil
        options.sessions = sessions
        self.options = options
    }

    func resetAll() {
        criteria = defaultCriteria
    }

    private func reloadCounters() {
        if mode == .network {
            guard let tasks = entities as? [NetworkTaskEntity] else {
                return assertionFailure()
            }
            domainsCountedSet = NSCountedSet(array: tasks.compactMap { $0.host })
            domains = index.hosts.sorted()
        } else {
            guard let messages = entities as? [LoggerMessageEntity] else {
                return assertionFailure()
            }
            labelsCountedSet = NSCountedSet(array: messages.map(\.label))
            labels = index.labels.sorted()
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
                return Set(index.labels).subtracting(criteria.messages.labels.hidden)
            }
        }
        set {
            criteria.messages.labels.focused = nil
            criteria.messages.labels.hidden = []
            switch newValue.count {
            case 1:
                criteria.messages.labels.focused = newValue.first!
            default:
                criteria.messages.labels.hidden = Set(index.labels).subtracting(newValue)
            }
        }
    }

    // MARK: Bindings (Hosts)

    var selectedHost: Set<String> {
        get {
            Set(index.hosts).subtracting(criteria.network.host.ignoredHosts)
        }
        set {
            criteria.network.host.ignoredHosts = Set(index.hosts).subtracting(newValue)
        }
    }
}
