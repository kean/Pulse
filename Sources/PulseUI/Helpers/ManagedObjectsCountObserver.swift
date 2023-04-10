// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData

final class ManagedObjectsCountObserver: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    let controller: NSFetchedResultsController<NSManagedObject>

    @Published private(set) var count = 0

    init<T: NSManagedObject>(entity: T.Type, context: NSManagedObjectContext, sortDescriptior: NSSortDescriptor) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "\(T.self)")
        request.fetchBatchSize = 1
        request.sortDescriptors = [sortDescriptior]

        self.controller = NSFetchedResultsController<NSManagedObject>(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

        super.init()

        self.controller.delegate = self
        self.refresh()
    }

    func setPredicate(_ predicate: NSPredicate?) {
        controller.fetchRequest.predicate = predicate
        refresh()
    }

    func refresh() {
        try? controller.performFetch()
        self.count = controller.fetchedObjects?.count ?? 0
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.count = controller.fetchedObjects?.count ?? 0
    }
}
