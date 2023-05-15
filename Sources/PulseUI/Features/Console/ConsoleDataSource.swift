// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

protocol ConsoleDataSourceDelegate: AnyObject {
    /// The data source reloaded the entire dataset.
    func dataSourceDidRefresh(_ dataSource: ConsoleDataSource)

    /// An incremental update. If the diff is nil, it means the app is displaying
    /// a grouped view that doesn't support diffing.
    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?)
}

final class ConsoleDataSource: NSObject, NSFetchedResultsControllerDelegate {
    weak var delegate: ConsoleDataSourceDelegate?

    /// - warning: Incompatible with the "group by" option.
    var sortDescriptors: [NSSortDescriptor] = [] {
        didSet { controller.fetchRequest.sortDescriptors = sortDescriptors }
    }

    struct PredicateOptions {
        var filters = ConsoleFilers()
        var isOnlyErrors = false
        var predicate: NSPredicate?
        var focus: NSPredicate?
    }

    var predicate: PredicateOptions = .init() {
        didSet { refreshPredicate() }
    }

    var filter: NSPredicate? {
        didSet { refreshPredicate() }
    }

    static let fetchBatchSize = 100

    private let store: LoggerStore
    private let mode: ConsoleMode
    private let options: ConsoleListOptions
    private let controller: NSFetchedResultsController<NSManagedObject>
    private var controllerDelegate: NSFetchedResultsControllerDelegate?
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, mode: ConsoleMode, options: ConsoleListOptions = .init()) {
        self.store = store
        self.mode = mode
        self.options = options

        let entityName: String
        let sortKey: String
        let grouping: ConsoleListGroupBy

        switch mode {
        case .all, .logs:
            entityName = "\(LoggerMessageEntity.self)"
            sortKey = options.messageSortBy.key
            grouping = options.messageGroupBy
        case .network:
            entityName = "\(NetworkTaskEntity.self)"
            sortKey = options.taskSortBy.key
            grouping = options.taskGroupBy
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = [
            grouping.key.flatMap {
                guard $0 != "session" else { return nil }
                return NSSortDescriptor(key: $0, ascending: grouping.isAscending)
            },
            NSSortDescriptor(key: sortKey, ascending: options.order == .ascending)
        ].compactMap { $0 }
        request.fetchBatchSize = ConsoleDataSource.fetchBatchSize
        request.relationshipKeyPathsForPrefetching = ["request"]
        controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: store.viewContext,
            sectionNameKeyPath: grouping.key,
            cacheName: nil
        )

        super.init()

        controllerDelegate = {
            if grouping.key == nil {
                let delegate = ConsoleFetchDelegate()
                delegate.delegate = self
                return delegate
            } else {
                let delegate = ConsoleGroupedFetchDelegate()
                delegate.delegate = self
                return delegate
            }
        }()
        controller.delegate = controllerDelegate
    }

    func bind(_ filters: ConsoleFiltersViewModel) {
        cancellables = []
        filters.$options.sink { [weak self] in
            self?.predicate = $0
        }.store(in: &cancellables)
    }

    func refresh() {
        try? controller.performFetch()
        delegate?.dataSourceDidRefresh(self)
    }
    
    // MARK: Accessing Entities
    
    var numberOfObjects: Int {
        controller.fetchedObjects?.count ?? 0
    }
    
    func object(at indexPath: IndexPath) -> NSManagedObject {
        controller.object(at: indexPath)
    }
    
    var entities: [NSManagedObject] {
        controller.fetchedObjects ?? []
    }
    
    var sections: [NSFetchedResultsSectionInfo]? {
        controller.sectionNameKeyPath == nil ? nil : controller.sections
    }
    
    // MARK: NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        delegate?.dataSource(self, didUpdateWith: nil)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        delegate?.dataSource(self, didUpdateWith: diff)
    }

    // MARK: Predicate

    private func refreshPredicate() {
        let predicate = ConsoleDataSource.makePredicate(mode: mode, options: predicate, filter: filter)
        controller.fetchRequest.predicate = predicate
        refresh()
    }

    static func makePredicate(mode: ConsoleMode, options: PredicateOptions, filter: NSPredicate? = nil) -> NSPredicate? {
        let predicates = [
            _makePredicate(mode, options.filters, options.isOnlyErrors),
            options.predicate,
            options.focus,
            filter
        ].compactMap { $0 }
        switch predicates.count {
        case 0: return nil
        case 1: return predicates[0]
        default: return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }

    func name(for section: NSFetchedResultsSectionInfo) -> String {
        makeName(for: section, mode: mode, options: options)
    }
}

// MARK: - Predicates

private func _makePredicate(_ mode: ConsoleMode, _ filters: ConsoleFilers, _ isOnlyErrors: Bool) -> NSPredicate? {
    func makeMessagesPredicate(isMessageOnly: Bool) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if isMessageOnly {
            predicates.append(NSPredicate(format: "task == NULL"))
        }
        if let predicate = ConsoleFilers.makeMessagePredicates(criteria: filters, isOnlyErrors: isOnlyErrors) {
            predicates.append(predicate)
        }
        return predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    switch mode {
    case .all:
        return makeMessagesPredicate(isMessageOnly: false)
    case .logs:
        return makeMessagesPredicate(isMessageOnly: true)
    case .network:
        return ConsoleFilers.makeNetworkPredicates(criteria: filters, isOnlyErrors: isOnlyErrors)
    }
}

// MARK: - Section Names

private func makeName(for section: NSFetchedResultsSectionInfo, mode: ConsoleMode, options: ConsoleListOptions) -> String {
    switch mode {
    case .all, .logs:
        switch options.messageGroupBy {
        case .level:
            let rawValue = Int16(Int(section.name) ?? 0)
            return (LoggerStore.Level(rawValue: rawValue) ?? .debug).name.capitalized
        case .session:
            let date = (section.objects?.last as? LoggerMessageEntity)?.createdAt
            return date.map(sessionDateFormatter.string) ?? "–"
        default:
            break
        }
    case .network:
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
            return date.map(sessionDateFormatter.string) ?? "–"
        default:
            break
        }
    }
    let name = section.name
    return name.isEmpty ? "–" : name
}

private let sessionDateFormatter = DateFormatter(dateStyle: .medium, timeStyle: .medium, isRelative: true)

// MARK: - Delegates

// Using a separate class because the diff API is not supported for a fetch
// controller with sections, and it prints an error message in logs if the
// delegate implements it, which we want to avoid.

private final class ConsoleFetchDelegate: NSObject, NSFetchedResultsControllerDelegate {
    weak var delegate: NSFetchedResultsControllerDelegate?

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        delegate?.controller?(controller, didChangeContentWith: diff)
    }
}

private final class ConsoleGroupedFetchDelegate: NSObject, NSFetchedResultsControllerDelegate {
    weak var delegate: NSFetchedResultsControllerDelegate?

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        delegate?.controllerDidChangeContent?(controller)
    }
}

enum ConsoleUpdateEvent {
    /// Full refresh of data.
    case refresh
    /// Incremental update.
    case update(CollectionDifference<NSManagedObjectID>?)
}
