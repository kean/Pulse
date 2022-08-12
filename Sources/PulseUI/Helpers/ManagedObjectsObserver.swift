// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

final class ManagedObjectsObserver<T: NSManagedObject>: NSObject, ObservableObject, NSFetchedResultsControllerDelegate {
    private let controller: NSFetchedResultsController<T>
    @Published private(set) var objects: [T] = []

    init(context: NSManagedObjectContext, sortDescriptior: NSSortDescriptor) {
        let request = NSFetchRequest<T>(entityName: "\(T.self)")
        request.fetchBatchSize = 100
        request.sortDescriptors = [sortDescriptior]

        self.controller = NSFetchedResultsController(fetchRequest: request, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)

        super.init()

        self.controller.delegate = self
        self.refresh()
    }

    private func refresh() {
        try? controller.performFetch()
        self.objects = controller.fetchedObjects ?? []
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.objects = self.controller.fetchedObjects ?? []
    }
}
