// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleListViewModel: ConsoleDataSourceDelegate, ObservableObject {
#if os(iOS) || os(visionOS)
    @Published private(set) var visibleEntities: ArraySlice<NSManagedObject> = []
#else
    var visibleEntities: [NSManagedObject] { entities }
#endif
    @Published private(set) var entities: [NSManagedObject] = []
    @Published private(set) var sections: [NSFetchedResultsSectionInfo]?

    /// Names of grouped sections the user has collapsed. Restored per
    /// `(mode, groupBy)` from on-disk cache when the data source is rebuilt.
    @Published var collapsedSections: Set<String> = []

    @Published private(set) var mode: ConsoleMode

    private var currentGroupByKey: String?
    private let collapsedSectionsCache = CollapsedSectionsCache.shared

    var isViewVisible = false {
        didSet {
            guard oldValue != isViewVisible else { return }
            if isViewVisible {
                resetDataSource(options: environment.listOptions)
            } else {
                dataSource = nil
            }
        }
    }

    @Published private(set) var previousSession: LoggerSessionEntity?
    @Published private(set) var allSessionsCount: Int = 0

    let events = PassthroughSubject<ConsoleUpdateEvent, Never>()

#if os(iOS) || os(visionOS)
    /// This exist strictly to workaround List performance issues
    private var scrollPosition: ScrollPosition = .nearTop
    private var visibleEntityCountLimit = ConsoleDataSource.fetchBatchSize
    private var visibleObjectIDs: Set<NSManagedObjectID> = []
#endif

    private let store: LoggerStoreProtocol
    private let environment: ConsoleEnvironment
    private let filters: ConsoleFiltersViewModel
    private let sessions: ManagedObjectsObserver<LoggerSessionEntity>
    @Published package private(set) var dataSource: ConsoleDataSource?
    private var cancellables: [AnyCancellable] = []
    private var filtersCancellable: AnyCancellable?

    init(environment: ConsoleEnvironment, filters: ConsoleFiltersViewModel) {
        self.store = environment.store
        self.environment = environment
        self.mode = environment.mode
        self.filters = filters
        self.sessions = .sessions(for: store.viewContext)
        self.allSessionsCount = self.sessions.objects.count

        $entities.sink { [weak self] in
            self?.filters.entities.send($0)
        }.store(in: &cancellables)

        sessions.$objects.dropFirst().sink { [weak self] in
            self?.allSessionsCount = $0.count
            self?.refreshPreviousSessionButton(sessions: $0)
        }.store(in: &cancellables)

        environment.$listOptions.dropFirst().sink { [weak self] in
            self?.resetDataSource(options: $0)
        }.store(in: &cancellables)

        environment.$mode.sink { [weak self] in
            self?.didUpdateMode($0)
        }.store(in: &cancellables)
    }

    private func didUpdateMode(_ mode: ConsoleMode) {
        self.mode = mode
        if isViewVisible {
            resetDataSource(options: environment.listOptions)
        }
    }

    private func resetDataSource(options: ConsoleListOptions) {
        dataSource = ConsoleDataSource(store: store, mode: mode, options: options)
        dataSource?.delegate = self
        let groupByKey = Self.groupByKey(mode: mode, options: options)
        currentGroupByKey = groupByKey
        collapsedSections = collapsedSectionsCache.sections(forKey: groupByKey)
        filtersCancellable = filters.$options.sink { [weak self] in
            self?.dataSource?.predicate = $0
        }
    }

    // MARK: Collapsible Sections

    func toggleSection(_ name: String) {
        if collapsedSections.contains(name) {
            collapsedSections.remove(name)
        } else {
            collapsedSections.insert(name)
        }
        if let key = currentGroupByKey {
            collapsedSectionsCache.setSections(collapsedSections, forKey: key)
        }
    }

    func collapseAllSections() {
        collapsedSections = Set((sections ?? []).map(\.name))
    }

    func expandAllSections() {
        collapsedSections.removeAll()
    }

    private static func groupByKey(mode: ConsoleMode, options: ConsoleListOptions) -> String {
        let groupBy: String
        switch mode {
        case .all, .logs: groupBy = options.messageGroupBy.rawValue
        case .network: groupBy = options.taskGroupBy.rawValue
        }
        return "\(mode.rawValue):\(groupBy)"
    }

    func buttonShowPreviousSessionTapped(for session: LoggerSessionEntity) {
        filters.sessions.insert(session.id)
        refreshPreviousSessionButton(sessions: self.sessions.objects)
    }

    private func refreshPreviousSessionButton(sessions: [LoggerSessionEntity]) {
        let selection = filters.sessions
        guard !selection.isEmpty else {
            previousSession = nil
            return
        }
        let isDisplayingPrefix = sessions.prefix(selection.count).allSatisfy {
            selection.contains($0.id)
        }
        guard isDisplayingPrefix,
              sessions.count > selection.count else {
            previousSession = nil
            return
        }
        previousSession = sessions[selection.count]
    }

    // MARK: ConsoleDataSourceDelegate

    func dataSourceDidRefresh(_ dataSource: ConsoleDataSource) {
        guard isViewVisible else { return }

        entities = dataSource.entities
        sections = dataSource.sections
        refreshPreviousSessionButton(sessions: sessions.objects)
#if os(iOS) || os(visionOS)
        refreshVisibleEntities()
#endif
        events.send(.refresh)
    }

    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?) {
        entities = dataSource.entities
        sections = dataSource.sections
#if os(iOS) || os(visionOS)
        if scrollPosition == .nearTop {
            refreshVisibleEntities()
        }
#endif
        events.send(.update(diff))
    }

    func name(for section: NSFetchedResultsSectionInfo) -> String {
        dataSource?.name(for: section) ?? ""
    }

    // MARK: Visible Entities

#if os(iOS) || os(visionOS)
    private enum ScrollPosition {
        case nearTop
        case middle
        case nearBottom
    }

    func onDisappearCell(with objectID: NSManagedObjectID) {
        visibleObjectIDs.remove(objectID)
        refreshScrollPosition()
    }

    func onAppearCell(with objectID: NSManagedObjectID) {
        visibleObjectIDs.insert(objectID)
        refreshScrollPosition()
    }

    private func refreshScrollPosition() {
        let scrollPosition: ScrollPosition
        if visibleObjectIDs.isEmpty || visibleEntities.prefix(5).map(\.objectID).contains(where: visibleObjectIDs.contains) {
            scrollPosition = .nearTop
        } else if visibleEntities.suffix(5).map(\.objectID).contains(where: visibleObjectIDs.contains) {
            scrollPosition = .nearBottom
        } else {
            scrollPosition = .middle
        }

        guard scrollPosition != self.scrollPosition else {
            return
        }
        self.scrollPosition = scrollPosition
        switch scrollPosition {
        case .nearTop:
            DispatchQueue.main.async {
                // Important: when we push a new screens all cells disappear
                // and the state transitions to .nearTop. We don't want the
                // view to reload when that happens.
                if self.isViewVisible {
                    self.refreshVisibleEntities()
                }
            }
        case .middle:
            break // Don't reload: too expensive and ruins gestures
        case .nearBottom:
            if visibleEntities.count < entities.count {
                visibleEntityCountLimit += ConsoleDataSource.fetchBatchSize
                refreshVisibleEntities()
            }
        }
    }

    private func refreshVisibleEntities() {
        visibleEntities = entities.prefix(visibleEntityCountLimit)
    }
#endif
}
