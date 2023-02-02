// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

#warning("this should not be a ViewModel and it should have a different name")
final class ConsoleListViewModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {
    @Published private(set) var visibleEntities: ArraySlice<NSManagedObject> = []
    @Published private(set) var pins: [NSManagedObject] = []
    @Published private(set) var entities: [NSManagedObject] = []
    @Published private(set) var sections: [NSFetchedResultsSectionInfo]?
    @Published var options = ConsoleListOptions()

#warning("remove")
    let entitiesSubject = CurrentValueSubject<[NSManagedObject], Never>([])
    let events = PassthroughSubject<ConsoleUpdateEvent, Never>()

    var isViewVisible = false {
        didSet {
            if isViewVisible {
                reloadMessages(isMandatory: true)
            }
        }
    }

#if os(macOS)
    var sortDescriptors: [NSSortDescriptor] = [] {
        didSet {
            controller?.fetchRequest.sortDescriptors = sortDescriptors
            try? controller?.performFetch()
            reloadMessages(isMandatory: true)
        }
    }
#endif

    var isShowPreviousSessionButtonShown: Bool {
        searchCriteriaViewModel.criteria.shared.dates == .session
    }

    @Published private(set) var mode: ConsoleMode = .all

    /// This exist strictly to workaround List performance issues
    private var scrollPosition: ScrollPosition = .nearTop
    private var visibleEntityCountLimit = fetchBatchSize
    private var visibleObjectIDs: Set<NSManagedObjectID> = []
    private var grouping: ConsoleListGroupBy { mode == .tasks ? options.taskGroupBy : options.messageGroupBy }

    let store: LoggerStore
    let source: ConsoleSource
    private let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    private let pinsController: NSFetchedResultsController<NSManagedObject>
    private var controller: NSFetchedResultsController<NSManagedObject>?
    private var cancellables: [AnyCancellable] = []

    let logCountObserver: ManagedObjectsCountObserver
    let taskCountObserver: ManagedObjectsCountObserver

    init(store: LoggerStore, source: ConsoleSource, criteria: ConsoleSearchCriteriaViewModel) {
        self.store = store
        self.source = source
        self.searchCriteriaViewModel = criteria

        self.logCountObserver = ManagedObjectsCountObserver(
            entity: LoggerMessageEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(key: "createdAt", ascending: false)
        )

        self.taskCountObserver = ManagedObjectsCountObserver(
            entity: NetworkTaskEntity.self,
            context: store.viewContext,
            sortDescriptior: NSSortDescriptor(key: "createdAt", ascending: false)
        )

        self.pinsController = NSFetchedResultsController(
            fetchRequest: {
                let request = NSFetchRequest<NSManagedObject>(entityName: "\(LoggerMessageEntity.self)")
                request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                return request
            }(),
            managedObjectContext: store.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

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

        $options.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refreshController()
        }.store(in: &cancellables)

        pinsController.delegate = self

        update(mode: mode)
    }

    func update(mode: ConsoleMode) {
        self.mode = mode

        self.refreshController()

        func makePinsFilter() -> NSPredicate? {
            switch mode {
            case .all: return nil
            case .logs: return NSPredicate(format: "task == NULL")
            case .tasks: return NSPredicate(format: "task != NULL")
            }
        }

        pinsController.fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "isPinned == YES"),
            makePinsFilter()
        ].compactMap { $0 })
        try? pinsController.performFetch()
        pins = pinsController.fetchedObjects ?? []
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

    // MARK: - NSFetchedResultsController

    func refreshController() {
        let request: NSFetchRequest<NSManagedObject>
        let sortKey = mode == .tasks ? options.taskSortBy.key : options.messageSortBy.key
        if mode == .tasks {
            request = .init(entityName: "\(NetworkTaskEntity.self)")
            request.sortDescriptors = [
                grouping.key.map { NSSortDescriptor(key: $0, ascending: grouping.isAscending) },
                NSSortDescriptor(key: sortKey, ascending: options.order == .ascending)
            ].compactMap { $0 }
        } else {
            request = .init(entityName: "\(LoggerMessageEntity.self)")
            request.relationshipKeyPathsForPrefetching = ["request"]
            request.sortDescriptors = [
                grouping.key.map { NSSortDescriptor(key: $0, ascending: grouping.isAscending) },
                NSSortDescriptor(key: sortKey, ascending: options.order == .ascending)
            ].compactMap { $0 }
        }
        request.fetchBatchSize = fetchBatchSize
        controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: store.viewContext,
            sectionNameKeyPath: grouping.key,
            cacheName: nil
        )
        controller?.delegate = self

        refresh()
    }

    func refresh() {
        guard let controller = controller else {
            return assertionFailure()
        }
        controller.fetchRequest.predicate = makePredicate(for: mode)
        try? controller.performFetch()

        logCountObserver.setPredicate(makePredicate(for: .logs))
        taskCountObserver.setPredicate(makePredicate(for: .tasks))

        reloadMessages()
        events.send(.reload)
    }

    private func makePredicate(for mode: ConsoleMode) -> NSPredicate? {
        switch source {
        case .store:
            return _makePredicate(for: mode)
        case .entities(_, let entities):
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                _makePredicate(for: mode),
                NSPredicate(format: "self IN %@", entities)
            ].compactMap { $0 })
        }
    }

    private func _makePredicate(for mode: ConsoleMode) -> NSPredicate? {
        let criteria = searchCriteriaViewModel

        func makeMessagesPredicate(isMessageOnly: Bool) -> NSPredicate? {
            var predicates: [NSPredicate] = []
            if isMessageOnly {
                predicates.append(NSPredicate(format: "task == NULL"))
            }
            if let predicate = ConsoleSearchCriteria.makeMessagePredicates(criteria: criteria.criteria, isOnlyErrors: criteria.isOnlyErrors, filterTerm: criteria.filterTerm) {
                predicates.append(predicate)
            }
            return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        switch mode {
        case .all:
            return makeMessagesPredicate(isMessageOnly: false)
        case .logs:
            return makeMessagesPredicate(isMessageOnly: true)
        case .tasks:
            return ConsoleSearchCriteria.makeNetworkPredicates(criteria: criteria.criteria, isOnlyErrors: criteria.isOnlyErrors, filterTerm: criteria.filterTerm)
        }
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        didRefreshContent()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        if pinsController === controller {
            withAnimation {
                pins = self.pinsController.fetchedObjects ?? []
            }
        } else {
            didRefreshContent()
            events.send(.diff(diff))
        }
    }

    private func didRefreshContent() {
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
        sections = controller?.sectionNameKeyPath == nil ?  nil : controller?.sections
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

    // MARK: - Sections

    private let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    func makeName(for section: NSFetchedResultsSectionInfo) -> String {
        switch mode {
        case .all, .logs:
            switch options.messageGroupBy {
            case .level:
                let rawValue = Int16(Int(section.name) ?? 0)
                return (LoggerStore.Level(rawValue: rawValue) ?? .debug).name.capitalized
            case .session:
                let date = (section.objects?.last as? LoggerMessageEntity)?.createdAt
                let suffix = date.map(sessionDateFormatter.string) ?? "–"
                return "#\(section.name) \(suffix)"
            default:
                break
            }
        case .tasks:
            switch options.taskGroupBy {
            case .taskType:
                let rawValue = Int16(Int(section.name) ?? 0)
                return NetworkLogger.TaskType(rawValue: rawValue)?.urlSessionTaskClassName ?? section.name
            case .statusCode:
                let rawValue = Int32(section.name) ?? 0
                return StatusCodeFormatter.string(for: rawValue)
            case .requestState:
                let rawValue = Int16(Int(section.name) ?? 0)
                guard let state = NetworkTaskEntity.State(rawValue: rawValue) else {
                    return "Unknown State"
                }
                switch state {
                case .pending: return "Pending"
                case .success: return "Success"
                case .failure: return "Failure"
                }
            case .session:
                let date = (section.objects?.last as? NetworkTaskEntity)?.createdAt
                let suffix = date.map(sessionDateFormatter.string) ?? "–"
                return "#\(section.name) \(suffix)"
            default:
                break
            }
        }
        let name = section.name
        return name.isEmpty ? "–" : name
    }

    // MARK: - Task Details

    struct TaskDetails {
        var totalRequestBodySize: Int64 = 0
        var totalResponseSize: Int64 = 0
        var totalDuration: TimeInterval = 0
    }

    var taskDetails: TaskDetails {
        var details = TaskDetails()
        for entity in entities {
            guard let task = mode == .tasks ? (entity as! NetworkTaskEntity) : (entity as! LoggerMessageEntity).task else {
                continue
            }
            details.totalRequestBodySize += task.requestBodySize
            details.totalResponseSize += task.responseBodySize
            details.totalDuration += task.duration
        }
        return details
    }
}

private let fetchBatchSize = 100

enum ConsoleUpdateEvent {
    /// Full reload.
    case reload
    /// An incremental update.
    case diff(CollectionDifference<NSManagedObjectID>)
}

enum ConsoleMode: String {
    case all
    case logs
    case tasks
}
