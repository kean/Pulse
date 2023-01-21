// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

final class ConsoleListViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    @Published private(set) var visibleEntities: ArraySlice<NSManagedObject> = []
    @Published private(set) var entities: [NSManagedObject] = []
    @Published private(set) var sections: [NSFetchedResultsSectionInfo]?
    @Published var options = ConsoleListOptions()

    let entitiesSubject = CurrentValueSubject<[NSManagedObject], Never>([])
    let didRefresh = PassthroughSubject<Void, Never>()

    var isViewVisible = false {
        didSet {
            if isViewVisible {
                reloadMessages(isMandatory: true)
            }
        }
    }

    /// This exist strickly to workaround List performance issues
    private var scrollPosition: ScrollPosition = .nearTop
    private var visibleEntityCountLimit = fetchBatchSize
    private var visibleObjectIDs: Set<NSManagedObjectID> = []

    private var isOnlyNetwork = false
    private let store: LoggerStore
    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    private var controller: NSFetchedResultsController<NSManagedObject>?
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, criteria: ConsoleSearchCriteriaViewModel) {
        self.store = store
        self.searchCriteriaViewModel = criteria

        super.init()

        $entities.sink { [entitiesSubject] in
            entitiesSubject.send($0)
        }.store(in: &cancellables)

        searchCriteriaViewModel.$criteria
            .dropFirst()
            .throttle(for: 0.5, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        searchCriteriaViewModel.$isOnlyErrors
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        searchCriteriaViewModel.$filterTerm
            .dropFirst()
            .throttle(for: 0.25, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // important: no drop first and refreshes immediatelly
        searchCriteriaViewModel.$isOnlyNetwork.sink { [weak self] in
            self?.isOnlyNetwork = $0
            self?.refreshController()
        }.store(in: &cancellables)

        $options.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refreshController()
        }.store(in: &cancellables)
    }

    func refreshController() {
        let request: NSFetchRequest<NSManagedObject>
        if isOnlyNetwork {
            request = .init(entityName: "\(NetworkTaskEntity.self)")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: options.order == .ascending)]
        } else {
            request = .init(entityName: "\(LoggerMessageEntity.self)")
            request.relationshipKeyPathsForPrefetching = ["request"]
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: options.order == .ascending)
            ]
        }
        request.fetchBatchSize = fetchBatchSize
        controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: store.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller?.delegate = self

        refresh()
    }

    func refresh() {
        // Search messages
        guard let controller = controller else {
            return assertionFailure()
        }
        let criteria = searchCriteriaViewModel
        if isOnlyNetwork {
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeNetworkPredicates(criteria: criteria.criteria, isOnlyErrors: criteria.isOnlyErrors, filterTerm: criteria.filterTerm)
        } else {
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeMessagePredicates(criteria: criteria.criteria, isOnlyErrors: criteria.isOnlyErrors, filterTerm: criteria.filterTerm)
        }
        try? controller.performFetch()

        reloadMessages()
        didRefresh.send(())
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        if isViewVisible {
            withAnimation {
                reloadMessages(isMandatory: false)
            }
        } else {
            entities = self.controller?.fetchedObjects ?? []
        }
    }

    private func reloadMessages(isMandatory: Bool = true) {
        entities = controller?.fetchedObjects ?? []
        if isMandatory || scrollPosition == .nearTop {
            refreshVisibleEntities()
        }
    }

    private func refreshVisibleEntities() {
        visibleEntities = entities.prefix(visibleEntityCountLimit)
    }

    // MARK: - Scroll Position

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
        if visibleEntities.prefix(5).map(\.objectID).contains(where: visibleObjectIDs.contains) {
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
                visibleEntityCountLimit = fetchBatchSize // Reset
                refreshVisibleEntities()
            case .middle:
                break // Don't reload: too expensive and ruins gestures
            case .nearBottom:
                visibleEntityCountLimit += fetchBatchSize
                refreshVisibleEntities()
            }
        }
    }
}

private let fetchBatchSize = 100
