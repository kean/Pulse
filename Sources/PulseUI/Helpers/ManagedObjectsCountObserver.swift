// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import CoreData

package final class ManagedObjectsCountObserver: ObservableObject {
    @Published private(set) package var count = 0

    private let viewContext: NSManagedObjectContext
    private let countContext: NSManagedObjectContext
    private let entityName: String
    private let request: NSFetchRequest<NSFetchRequestResult>
    private var observer: NSObjectProtocol?
    private var needsRefresh = false

    package init<T: NSManagedObject>(entity: T.Type, context: NSManagedObjectContext) {
        self.viewContext = context
        self.entityName = "\(T.self)"
        self.request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)

        let countContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        countContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        self.countContext = countContext

        refresh()

        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: context,
            queue: nil
        ) { [weak self] notification in
            guard let self, self.isRelevantChange(notification) else { return }
            self.scheduleRefresh()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    package func setPredicate(_ predicate: NSPredicate?) {
        request.predicate = predicate
        scheduleRefresh()
    }

    /// Synchronously recomputes the count on the view context. Used for the
    /// initial population and in tests that want a deterministic read.
    package func refresh() {
        count = (try? viewContext.count(for: request)) ?? 0
    }

    private func scheduleRefresh() {
        guard !needsRefresh else { return }
        needsRefresh = true
        DispatchQueue.main.async { [weak self] in
            self?.performScheduledRefresh()
        }
    }

    private func performScheduledRefresh() {
        needsRefresh = false
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        request.predicate = self.request.predicate
        countContext.perform { [weak self] in
            guard let self else { return }
            let count = (try? self.countContext.count(for: request)) ?? 0
            DispatchQueue.main.async { [weak self] in
                guard let self, self.count != count else { return }
                self.count = count
            }
        }
    }

    private func isRelevantChange(_ notification: Notification) -> Bool {
        let keys = [NSInsertedObjectsKey, NSDeletedObjectsKey, NSUpdatedObjectsKey, NSRefreshedObjectsKey]
        for key in keys {
            if let objects = notification.userInfo?[key] as? Set<NSManagedObject>,
               objects.contains(where: { $0.entity.name == entityName }) {
                return true
            }
        }
        return false
    }
}
