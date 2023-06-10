// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleListViewModel: ConsoleDataSourceDelegate, ObservableObject, ConsoleEntitiesSource {
#if !os(macOS)
    @Published private(set) var visibleEntities: ArraySlice<NSManagedObject> = []
#else
    var visibleEntities: [NSManagedObject] { entities }
#endif
    @Published private(set) var pins: [NSManagedObject] = []
    @Published private(set) var entities: [NSManagedObject] = []
    @Published private(set) var sections: [NSFetchedResultsSectionInfo]?

    @Published private(set) var mode: ConsoleMode

    var didLiveScrollCancellable: AnyCancellable?

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

    var isShowingFocusedEntities: Bool {
        filters.options.focus != nil
    }

    @Published private(set) var previousSession: LoggerSessionEntity?

    let events = PassthroughSubject<ConsoleUpdateEvent, Never>()

    /// This exist strictly to workaround List performance issues
    private var scrollPosition: ScrollPosition = .nearTop
    private var visibleEntityCountLimit = ConsoleDataSource.fetchBatchSize
    private var visibleObjectIDs: Set<NSManagedObjectID> = []

    private let store: LoggerStore
    private let environment: ConsoleEnvironment
    private let filters: ConsoleFiltersViewModel
    private let sessions: ManagedObjectsObserver<LoggerSessionEntity>
    private let pinsObserver: ManagedObjectsObserver<LoggerMessageEntity>
    private var dataSource: ConsoleDataSource?
    private var cancellables: [AnyCancellable] = []
    private var filtersCancellable: AnyCancellable?

    init(environment: ConsoleEnvironment, filters: ConsoleFiltersViewModel) {
        self.store = environment.store
        self.environment = environment
        self.mode = environment.mode
        self.filters = filters
        self.sessions = .sessions(for: store.viewContext)
        self.pinsObserver = .pins(for: store.viewContext)

        $entities.sink { [weak self] in
            self?.filters.entities.send($0)
        }.store(in: &cancellables)

        sessions.$objects.dropFirst().sink { [weak self] in
            self?.refreshPreviousSessionButton(sessions: $0)
        }.store(in: &cancellables)

        pinsObserver.$objects.dropFirst().sink { [weak self] pins in
            guard let self = self else { return }
            withAnimation {
                self.pins = filter(pins: pins, mode: self.mode)
            }
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
        pins = filter(pins: pinsObserver.objects, mode: mode)
        if isViewVisible {
            resetDataSource(options: environment.listOptions)
        }
    }

    private func resetDataSource(options: ConsoleListOptions) {
        dataSource = ConsoleDataSource(store: store, mode: mode, options: options)
        dataSource?.delegate = self
        filtersCancellable = filters.$options.sink { [weak self] in
            self?.dataSource?.predicate = $0
        }
    }

    func focus(on entities: [NSManagedObject]) {
        environment.listOptions.messageGroupBy = .noGrouping
        environment.listOptions.taskGroupBy = .noGrouping
        filters.options.focus = NSPredicate(format: "self IN %@", entities)
    }

    func buttonShowPreviousSessionTapped(for session: LoggerSessionEntity) {
        filters.criteria.shared.sessions.selection.insert(session.id)
        refreshPreviousSessionButton(sessions: self.sessions.objects)
    }

    func buttonRemovePinsTapped() {
        store.pins.removeAllPins()
    }

    private func refreshPreviousSessionButton(sessions: [LoggerSessionEntity]) {
        let selection = filters.criteria.shared.sessions.selection
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
#if !os(macOS)
        refreshVisibleEntities()
#endif
        events.send(.refresh)
    }

    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?) {
        entities = dataSource.entities
        sections = dataSource.sections
#if !os(macOS)
        if scrollPosition == .nearTop {
            refreshVisibleEntities()
        }
#endif
        events.send(.update(diff))
    }

    // MARK: Visible Entities

    private enum ScrollPosition {
        case nearTop
        case middle
        case nearBottom
    }

    func onDisappearCell(with objectID: NSManagedObjectID) {
#if !os(macOS)
        visibleObjectIDs.remove(objectID)
        refreshScrollPosition()
#endif
    }

    func onAppearCell(with objectID: NSManagedObjectID) {
#if !os(macOS)
        visibleObjectIDs.insert(objectID)
        refreshScrollPosition()
#endif
    }

#if !os(macOS)
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

    // MARK: Sections

    func name(for section: NSFetchedResultsSectionInfo) -> String {
        dataSource?.name(for: section) ?? ""
    }
}

private func filter(pins: [LoggerMessageEntity], mode: ConsoleMode) -> [LoggerMessageEntity] {
    pins.filter {
        switch mode {
        case .all: return true
        case .logs: return $0.task == nil
        case .network: return $0.task != nil
        }
    }
}
