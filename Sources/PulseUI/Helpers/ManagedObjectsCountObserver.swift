// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import CoreData

package final class ManagedObjectsCountObserver: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    package let controller: NSFetchedResultsController<NSManagedObject>

    @Published private(set) package var count = 0

    package init<T: NSManagedObject>(entity: T.Type, context: NSManagedObjectContext, sortDescriptior: NSSortDescriptor) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "\(T.self)")
        request.fetchBatchSize = 1
        request.sortDescriptors = [sortDescriptior]

        self.controller = NSFetchedResultsController<NSManagedObject>(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

        super.init()

        self.controller.delegate = self
        self.refresh()
    }

    package func setPredicate(_ predicate: NSPredicate?) {
        controller.fetchRequest.predicate = predicate
        refresh()
    }

    package func refresh() {
        try? controller.performFetch()
        self.count = controller.fetchedObjects?.count ?? 0
    }

    package func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.count = controller.fetchedObjects?.count ?? 0
    }
}
