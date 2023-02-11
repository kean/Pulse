// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

/// Manages the logs list. Supports grouping, ordering, pins.
///
/// - note: It currently acts as a source of entities for other screen as well
/// and should probably be extracted to a separate class.
final class ConsoleListViewModel: ConsoleDataSourceDelegate, ObservableObject {
    @Published private(set) var visibleEntities: ArraySlice<NSManagedObject> = []
    @Published private(set) var pins: [NSManagedObject] = []
    @Published private(set) var entities: [NSManagedObject] = []
    @Published private(set) var sections: [NSFetchedResultsSectionInfo]?
    @Published var options = ConsoleListOptions()

    var isViewVisible = false {
        didSet {
            if isViewVisible {
                resetDataSource(options: options)
            } else {
                dataSource = nil
            }
        }
    }

#warning("reimplement")
    var sortDescriptors: [NSSortDescriptor] = [] {
        didSet {
//            controller?.fetchRequest.sortDescriptors = sortDescriptors
//            try? controller?.performFetch()
//            reloadMessages()
        }
    }

    var isShowPreviousSessionButtonShown: Bool {
        searchCriteriaViewModel.criteria.shared.dates == .session
    }

    var mode: ConsoleMode = .all {
        didSet {
            pins = filter(pins: pinsObserver.pins, mode: mode)
            resetDataSource(options: options)
        }
    }

    /// This exist strictly to workaround List performance issues
    private var scrollPosition: ScrollPosition = .nearTop
    private var visibleEntityCountLimit = ConsoleDataSource.fetchBatchSize
    private var visibleObjectIDs: Set<NSManagedObjectID> = []

    let store: LoggerStore
    let source: ConsoleSource
    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    private let pinsObserver: LoggerPinsObserver
    private var dataSource: ConsoleDataSource?
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, source: ConsoleSource, criteria: ConsoleSearchCriteriaViewModel) {
        self.store = store
        self.source = source
        self.searchCriteriaViewModel = criteria
        self.pinsObserver = LoggerPinsObserver(store: store)
        self.bind()
    }

    private func bind() {
        pinsObserver.$pins.dropFirst().sink { [weak self] pins in
            guard let self = self else { return }
            withAnimation {
                self.pins = filter(pins: pins, mode: self.mode)
            }
        }.store(in: &cancellables)

        searchCriteriaViewModel.$criteria
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        searchCriteriaViewModel.$isOnlyErrors
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        $options.dropFirst()
            .sink { [weak self] in self?.resetDataSource(options: $0) }
            .store(in: &cancellables)
    }

    private func resetDataSource(options: ConsoleListOptions) {
        dataSource = ConsoleDataSource(store: store, source: source, mode: mode, options: options)
        dataSource?.delegate = self
        refresh()
    }

    func buttonShowPreviousSessionTapped() {
        searchCriteriaViewModel.criteria.shared.dates.startDate = nil
    }

    func buttonRemovePinsTapped() {
        store.pins.removeAllPins()
    }

    func entity(withID objectID: NSManagedObjectID) -> NSManagedObject? {
        try? store.viewContext.existingObject(with: objectID)
    }

    // MARK: ConsoleDataSourceDelegate

    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?) {
        withAnimation {
            entities = dataSource.entities
            sections = dataSource.sections
            if scrollPosition == .nearTop {
                refreshVisibleEntities()
            }
        }
    }

    func refresh() {
        guard let dataSource = dataSource else { return }

        let criteria = searchCriteriaViewModel
        dataSource.setPredicate(criteria: criteria.criteria, isOnlyErrors: criteria.isOnlyErrors)
        dataSource.refresh()

        entities = dataSource.entities
        sections = dataSource.sections

        refreshVisibleEntities()
    }

    // MARK: Visible Entities

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

        if scrollPosition != self.scrollPosition {
            self.scrollPosition = scrollPosition
            switch scrollPosition {
            case .nearTop:
                visibleEntityCountLimit = ConsoleDataSource.fetchBatchSize // Reset
                refreshVisibleEntities()
            case .middle:
                break // Don't reload: too expensive and ruins gestures
            case .nearBottom:
                visibleEntityCountLimit += ConsoleDataSource.fetchBatchSize
                refreshVisibleEntities()
            }
        }
    }

    private func refreshVisibleEntities() {
        visibleEntities = entities.prefix(visibleEntityCountLimit)
    }

    // MARK: Sections

    func name(for section: NSFetchedResultsSectionInfo) -> String {
        dataSource?.name(for: section) ?? ""
    }
}

enum ConsoleMode: String {
    case all
    case logs
    case tasks
}

// MARK: Helpers

private func filter(pins: [LoggerMessageEntity], mode: ConsoleMode) -> [LoggerMessageEntity] {
    pins.filter {
        switch mode {
        case .all: return true
        case .logs: return $0.task == nil
        case .tasks: return $0.task != nil
        }
    }
}
