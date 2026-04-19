// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

package protocol ConsoleDataSourceDelegate: AnyObject {
    /// The data source reloaded the entire dataset.
    func dataSourceDidRefresh(_ dataSource: ConsoleDataSource)

    /// An incremental update. If the diff is nil, it means the app is displaying
    /// a grouped view that doesn't support diffing.
    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?)
}

package final class ConsoleDataSource: NSObject, NSFetchedResultsControllerDelegate {
    package weak var delegate: ConsoleDataSourceDelegate?

    /// - warning: Incompatible with the "group by" option.
    package var sortDescriptors: [NSSortDescriptor] = [] {
        didSet { controller.fetchRequest.sortDescriptors = sortDescriptors }
    }

    package var predicate: ConsoleListPredicateOptions = .init() {
        didSet { refreshPredicate() }
    }

    package var filter: NSPredicate? {
        didSet { refreshPredicate() }
    }

    package static let fetchBatchSize = 100

    package let store: LoggerStoreProtocol
    package let mode: ConsoleMode
    private let options: ConsoleListOptions
    private let controller: NSFetchedResultsController<NSManagedObject>
    private var controllerDelegate: NSFetchedResultsControllerDelegate?
    private var cancellables: [AnyCancellable] = []

    package init(store: LoggerStoreProtocol, mode: ConsoleMode, options: ConsoleListOptions = .init()) {
        self.store = store
        self.mode = mode
        self.options = options

        let sortKey: String
        let grouping: ConsoleListGroupBy

        switch mode {
        case .all, .logs:
            sortKey = options.messageSortBy.key
            grouping = options.messageGroupBy
        case .network:
            sortKey = options.taskSortBy.key
            grouping = options.taskGroupBy
        }
        let entityName = mode.entityName

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = [
            grouping.key.flatMap {
                guard $0 != "session" else { return nil }
                return NSSortDescriptor(key: $0, ascending: grouping.isAscending)
            },
            NSSortDescriptor(key: sortKey, ascending: options.order == .ascending)
        ].compactMap { $0 }
        request.fetchBatchSize = ConsoleDataSource.fetchBatchSize
        if mode != .network {
            request.relationshipKeyPathsForPrefetching = ["request"]
        }
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

    package func bind(_ filters: ConsoleFiltersViewModel) {
        cancellables = []
        filters.$options.sink { [weak self] in
            self?.predicate = $0
        }.store(in: &cancellables)
    }

    package func refresh() {
        try? controller.performFetch()
        delegate?.dataSourceDidRefresh(self)
    }

    // MARK: Accessing Entities

    package var numberOfObjects: Int {
        controller.fetchedObjects?.count ?? 0
    }

    package func object(at indexPath: IndexPath) -> NSManagedObject {
        controller.object(at: indexPath)
    }

    package var entities: [NSManagedObject] {
        controller.fetchedObjects ?? []
    }

    package var sections: [NSFetchedResultsSectionInfo]? {
        controller.sectionNameKeyPath == nil ? nil : controller.sections
    }

#if os(iOS) || os(macOS) || os(visionOS)
    // MARK: Search

    @available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
    package func makeSearchSession(
        parameters: ConsoleSearchParameters,
        extendedPredicate: NSPredicate? = nil,
        extendedFetchLimit: Int = 1000
    ) -> ConsoleSearchSession {
        ConsoleSearchSession(
            store: store,
            mode: mode,
            primaryPredicate: controller.fetchRequest.predicate,
            extendedPredicate: extendedPredicate,
            extendedFetchLimit: extendedFetchLimit,
            sortDescriptors: controller.fetchRequest.sortDescriptors ?? [],
            parameters: parameters
        )
    }
#endif

    // MARK: NSFetchedResultsControllerDelegate

    package func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        delegate?.dataSource(self, didUpdateWith: nil)
    }

    package func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        delegate?.dataSource(self, didUpdateWith: diff)
    }

    // MARK: Predicate

    private func refreshPredicate() {
        let predicate = ConsoleDataSource.makePredicate(mode: mode, options: predicate, filter: filter)
        controller.fetchRequest.predicate = predicate
        refresh()
    }

    package static func makePredicate(mode: ConsoleMode, options: ConsoleListPredicateOptions, filter: NSPredicate? = nil) -> NSPredicate? {
        let predicates = [
            _makePredicate(mode, options),
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

    package func name(for section: NSFetchedResultsSectionInfo) -> String {
        makeName(for: section, mode: mode, options: options)
    }
}

// MARK: - Predicates

private func _makePredicate(_ mode: ConsoleMode, _ options: ConsoleListPredicateOptions) -> NSPredicate? {
    let filters = options.filters
    let sessions = options.sessions
    let isOnlyErrors = options.isOnlyErrors

    func makeMessagesPredicate(isMessageOnly: Bool) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if isMessageOnly {
            predicates.append(NSPredicate(format: "task == NULL"))
        }
        if let predicate = ConsoleFilters.makeMessagePredicates(criteria: filters, sessions: sessions, isOnlyErrors: isOnlyErrors) {
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
        return ConsoleFilters.makeNetworkPredicates(criteria: filters, sessions: sessions, isOnlyErrors: isOnlyErrors)
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
