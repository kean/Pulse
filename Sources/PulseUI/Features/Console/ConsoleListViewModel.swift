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

#warning("remove subject")
    let entitiesSubject = CurrentValueSubject<[NSManagedObject], Never>([])

    // Sorting/Grouping
    @Published var messageSortBy: ConsoleMessageSortBy = .dateCreated
    @Published var taskSortBy: ConsoleTaskSortBy = .dateCreated
    @Published var order: ConsoleOrdering = .descending
    @Published var messageGroupBy: ConsoleMessageGroupBy = .plain
    @Published var taskGroupBy: ConsoleTaskGroupBy = .plain

    var isViewVisible = false {
        didSet {
            if isViewVisible {
                reloadMessages(isMandatory: true)
            }
        }
    }

    var mode: ConsoleMode

    /// This exist strickly to workaround List performance issues
    private var scrollPosition: ScrollPosition = .nearTop
    private var visibleEntityCountLimit = fetchBatchSize
    private var visibleObjectIDs: Set<NSManagedObjectID> = []

    private let store: LoggerStore
    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    private var controller: NSFetchedResultsController<NSManagedObject>?
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: ConsoleMode, criteria: ConsoleSearchCriteriaViewModel) {
        self.store = store
        self.mode = mode
        self.searchCriteriaViewModel = criteria

        super.init()

        $entities.sink { [entitiesSubject] in
            entitiesSubject.send($0)
        }.store(in: &cancellables)

        $order.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refreshController()
        }.store(in: &cancellables)
    }

    func refreshController() {
        let request = makeFetchRequest(for: mode, order: order)
        controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: store.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        controller?.delegate = self

#warning("where do we get the search criteria from?")
        refresh()
    }

    #warning("remove filter term parametes?")
    func refresh(isOnlyErrors: Bool = false, filterTerm: String = "") {
        // Search messages
        guard let controller = controller else {
            return assertionFailure()
        }
        switch mode {
        case .messages:
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeMessagePredicates(criteria: searchCriteriaViewModel.criteria, isOnlyErrors: isOnlyErrors, filterTerm: filterTerm)
        case .network:
            controller.fetchRequest.predicate = ConsoleSearchCriteria.makeNetworkPredicates(criteria: searchCriteriaViewModel.criteria, isOnlyErrors: isOnlyErrors, filterTerm: filterTerm)
        }
        try? controller.performFetch()
        reloadMessages()
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

private func makeFetchRequest(for mode: ConsoleMode, order: ConsoleOrdering) -> NSFetchRequest<NSManagedObject> {
    let request: NSFetchRequest<NSManagedObject>
    switch mode {
    case .messages:
        request = .init(entityName: "\(LoggerMessageEntity.self)")
        request.relationshipKeyPathsForPrefetching = ["request"]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LoggerMessageEntity.createdAt, ascending: order == .ascending)]
    case .network:
        request = .init(entityName: "\(NetworkTaskEntity.self)")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NetworkTaskEntity.createdAt, ascending: order == .ascending)]
    }
    request.fetchBatchSize = fetchBatchSize
    return request
}

private let fetchBatchSize = 100

enum ConsoleOrdering: String, CaseIterable {
    case descending = "Descending"
    case ascending = "Ascending"
}

enum ConsoleMessageSortBy: String, CaseIterable {
    case dateCreated = "Date Created"
}

enum ConsoleTaskSortBy: String, CaseIterable {
    case dateCreated = "Date Created"
    case duration = "Duration"
    case requestSize = "Request Size"
    case responseSize = "Response Size"
}

enum ConsoleMessageGroupBy: String, CaseIterable {
    case plain = "None"
    case label = "Label"
    case level = "Level"
    case file = "File"
}

#warning("remove none")
enum ConsoleTaskGroupBy: String, CaseIterable {
    case plain = "None"
    case url = "URL"
    case host = "Host"
    case method = "Method"
    case scheme = "Scheme"
    case taskType = "Task Type"
    case statusCode = "Status Code"
    case errorCode = "Error Code"
}
