// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import CoreData
import Pulse
import Combine
import SwiftUI

package final class ConsoleFiltersViewModel: ObservableObject {
    @Published package var mode: ConsoleMode = .all
    @Published package var options = ConsoleListPredicateOptions()

    package var criteria: ConsoleFilters {
        get { options.filters }
        set { options.filters = newValue }
    }

    package var sessions: Set<UUID> {
        get { options.sessions }
        set { options.sessions = newValue }
    }

    package let defaultCriteria: ConsoleFilters

    // TODO: Refactor
    package let entities = CurrentValueSubject<[NSManagedObject], Never>([])

#if os(iOS) || os(macOS) || os(visionOS)
    /// One store per mode — recents in network mode shouldn't appear when the
    /// user is in logs mode.
    private var recentStores: [ConsoleMode: ConsoleRecentFiltersStore] = [:]

    package func recentFiltersStore(for mode: ConsoleMode) -> ConsoleRecentFiltersStore {
        if let existing = recentStores[mode] {
            return existing
        }
        let store = ConsoleRecentFiltersStore(mode: mode)
        recentStores[mode] = store
        return store
    }
#endif

    package init(options: ConsoleListPredicateOptions) {
        self.options = options
        self.defaultCriteria = options.filters
    }

    // MARK: Helpers

    package func isDefaultFilters(for mode: ConsoleMode) -> Bool {
        guard criteria.shared == defaultCriteria.shared else { return false }
        if mode == .network {
            return criteria.network == defaultCriteria.network
        } else {
            return criteria.messages == defaultCriteria.messages
        }
    }

    package func resetAll() {
        criteria = defaultCriteria
    }

#if os(iOS) || os(macOS) || os(visionOS)
    /// Snapshots the current filters into the per-mode recents store. Called
    /// when the filters sheet dismisses. No-ops on default/empty filter sets
    /// (handled by the store itself).
    package func snapshotRecentFilters() {
        guard !isDefaultFilters(for: mode) else { return }
        recentFiltersStore(for: mode).save(criteria)
    }

    /// Applies a recent filter set to the current criteria. Session selection
    /// is unaffected because it lives outside of `ConsoleFilters`.
    package func apply(_ entry: ConsoleRecentFilter) {
        criteria = entry.filters
    }
#endif
}
