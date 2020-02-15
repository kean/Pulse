// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import CoreData
import Herald

final class FetchedEntities<Element: NSManagedObject>: NSObject, NSFetchedResultsControllerDelegate, RandomAccessCollection, ObservableObject {
    private let controller: NSFetchedResultsController<Element>

    init(context: NSManagedObjectContext, request: NSFetchRequest<Element>) {
        self.controller = NSFetchedResultsController<Element>(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        super.init()
        self.controller.delegate = self
        try? self.controller.performFetch()
    }

    convenience init<Value>(context: NSManagedObjectContext, sortedBy keyPath: KeyPath<Element, Value>, ascending: Bool = true) {
        let request = NSFetchRequest<Element>(entityName: Element.entity().name!)
        request.sortDescriptors = [NSSortDescriptor(keyPath: keyPath, ascending: ascending)]
        self.init(context: context, request: request)
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        objectWillChange.send()
    }

    // MARK: - Collection

    typealias Index = Int

    var startIndex: Index { return controller.fetchedObjects?.startIndex ?? 0 }
    var endIndex: Index { return controller.fetchedObjects?.endIndex ?? 0 }
    func index(after i: Index) -> Index { i + 1 }

    subscript(index: Index) -> Element {
        get { return controller.object(at: IndexPath(row: index, section: 0)) }
    }
}
