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

    @Published private(set) var domains: [String] = []

    private(set) var domainsCountedSet = NSCountedSet()

    let defaultCriteria: ConsoleSearchCriteria

    // TODO: Refactor
    let entities = CurrentValueSubject<[NSManagedObject], Never>([])

    private let index: LoggerStoreIndex

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

#if os(macOS)
    func focus(on entities: [NSManagedObject]) {
        options.focus = NSPredicate(format: "self IN %@", entities)
    }
#endif

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
