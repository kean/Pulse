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

    @Published private(set) var labels: [String] = []
    @Published private(set) var domains: [String] = []

    private(set) var labelsCountedSet = NSCountedSet()
    private(set) var domainsCountedSet = NSCountedSet()

    let defaultCriteria: ConsoleSearchCriteria

    private let index: LoggerStoreIndex
    private var isScreenVisible = false
    private var entities: [NSManagedObject] = []
    private var cancellables: [AnyCancellable] = []

    /// Initializes the view model with the initial criteria.
    ///
    /// - Parameters:
    ///   - criteria: The initial search criteria.
    ///   - index: The store index.
    init(options: ConsolePredicateOptions, index: LoggerStoreIndex) {
        self.index = index
        self.options = options
        self.defaultCriteria = options.criteria
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

#if os(macOS)
    func focus(on entities: [NSManagedObject]) {
        options.focus = NSPredicate(format: "self IN %@", entities)
    }
#endif

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
        self.criteria.shared.sessions.selection = sessions
    }

    func resetAll() {
        criteria = defaultCriteria
    }

    private func reloadCounters() {
        if let tasks = entities as? [NetworkTaskEntity] {
            domainsCountedSet = NSCountedSet(array: tasks.compactMap { $0.host })
            domains = index.hosts.sorted()
        } else if let messages = entities as? [LoggerMessageEntity] {
            labelsCountedSet = NSCountedSet(array: messages.map(\.label))
            labels = index.labels.sorted()
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
