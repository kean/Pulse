// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData
import Pulse
import Combine
import SwiftUI

protocol ConsoleDataSourceDelegate: AnyObject {
    /// An incremental update. If the diff is nil, it means the app is displaying
    /// a grouped view that doesn't support diffing.
    func dataSource(_ dataSource: ConsoleDataSource, didUpdateWith diff: CollectionDifference<NSManagedObjectID>?)
}

final class ConsoleDataSource: NSObject, NSFetchedResultsControllerDelegate {
    @Published private(set) var entities: [NSManagedObject] = []
    @Published private(set) var sections: [NSFetchedResultsSectionInfo]?

    weak var delegate: ConsoleDataSourceDelegate?

    /// - warning: Incompatible with the "group by" option.
    var sortDescriptors: [NSSortDescriptor] = [] {
        didSet { controller.fetchRequest.sortDescriptors = sortDescriptors }
    }

    static let fetchBatchSize = 100

    private let store: LoggerStore
    private let source: ConsoleSource
    private let mode: ConsoleMode
    private let options: ConsoleListOptions
    private let controller: NSFetchedResultsController<NSManagedObject>
    private var controllerDelegate: NSFetchedResultsControllerDelegate?

    init(store: LoggerStore, source: ConsoleSource, mode: ConsoleMode, options: ConsoleListOptions) {
        self.store = store
        self.source = source
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
        case .tasks:
            entityName = "\(NetworkTaskEntity.self)"
            sortKey = options.taskSortBy.key
            grouping = options.taskGroupBy
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.sortDescriptors = [
            grouping.key.map { NSSortDescriptor(key: $0, ascending: grouping.isAscending) },
            NSSortDescriptor(key: sortKey, ascending: options.order == .ascending)
        ].compactMap { $0 }
        request.fetchBatchSize = ConsoleDataSource.fetchBatchSize
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

    func refresh() {
        try? controller.performFetch()
        refreshEntities()
    }

    // MARK: NSFetchedResultsControllerDelegate

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        refreshEntities()
        delegate?.dataSource(self, didUpdateWith: nil)
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith diff: CollectionDifference<NSManagedObjectID>) {
        refreshEntities()
        delegate?.dataSource(self, didUpdateWith: diff)
    }

    private func refreshEntities() {
        entities = controller.fetchedObjects ?? []
        sections = controller.sectionNameKeyPath == nil ?  nil : controller.sections
    }

    // MARK: Predicate

    func setPredicate(wih criteria: ConsoleSearchCriteria, isOnlyErrors: Bool) {
        let predicate = ConsoleDataSource.makePredicate(mode: mode, source: source, criteria: criteria, isOnlyErrors: isOnlyErrors)
        controller.fetchRequest.predicate = predicate
    }

    static func makePredicate(mode: ConsoleMode, source: ConsoleSource, criteria: ConsoleSearchCriteria, isOnlyErrors: Bool) -> NSPredicate? {
        let mainPredicate = _makePredicate(mode, criteria, isOnlyErrors)
        switch source {
        case .store:
            return mainPredicate
        case .entities(_, let entities):
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                mainPredicate,
                NSPredicate(format: "self IN %@", entities)
            ].compactMap { $0 })
        }
    }

    func name(for section: NSFetchedResultsSectionInfo) -> String {
        makeName(for: section, mode: mode, options: options)
    }
}

// MARK: - Predicates

private func _makePredicate(_ mode: ConsoleMode, _ criteria: ConsoleSearchCriteria, _ isOnlyErrors: Bool) -> NSPredicate? {
    func makeMessagesPredicate(isMessageOnly: Bool) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if isMessageOnly {
            predicates.append(NSPredicate(format: "task == NULL"))
        }
        if let predicate = ConsoleSearchCriteria.makeMessagePredicates(criteria: criteria, isOnlyErrors: isOnlyErrors) {
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
        return ConsoleSearchCriteria.makeNetworkPredicates(criteria: criteria, isOnlyErrors: isOnlyErrors)
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

private let sessionDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateStyle = .medium
    formatter.timeStyle = .medium
    formatter.doesRelativeDateFormatting = true
    return formatter
}()

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
