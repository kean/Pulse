// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

extension NSManagedObjectContext {
    func fetch<T: NSManagedObject>(_ entity: T.Type, _ configure: (NSFetchRequest<T>) -> Void = { _ in }) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: entity))
        configure(request)
        return try fetch(request)
    }

    func fetch<T: NSManagedObject, Value>(_ entity: T.Type, sortedBy keyPath: KeyPath<T, Value>, ascending: Bool = true,  _ configure: (NSFetchRequest<T>) -> Void = { _ in }) throws -> [T] {
        try fetch(entity) {
            $0.sortDescriptors = [NSSortDescriptor(keyPath: keyPath, ascending: ascending)]
        }
    }

    func first<T: NSManagedObject>(_ entity: T.Type, _ configure: (NSFetchRequest<T>) -> Void = { _ in }) throws -> T? {
        try fetch(entity) {
            $0.fetchLimit = 1
            configure($0)
        }.first
    }

    func count<T: NSManagedObject>(for entity: T.Type) throws -> Int {
        try count(for: NSFetchRequest<T>(entityName: String(describing: entity)))
    }

    func performAndReturn<T>(_ closure: () throws -> T) throws -> T {
        var result: Result<T, Error>?
        performAndWait {
            result = Result { try closure() }
        }
        guard let result else { throw LoggerStore.Error.unknownError }
        return try result.get()
    }
}

extension NSPersistentContainer {
    static var inMemoryReadonlyContainer: NSPersistentContainer {
        let container = NSPersistentContainer(name: "EmptyStore", managedObjectModel: LoggerStore.model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, _ in }
        return container
    }

    func loadStore() throws {
        var loadError: Swift.Error?
        loadPersistentStores { description, error in
            if let error = error {
                debugPrint("Failed to load persistent store \(description) with error: \(error)")
                loadError = error
            }
        }
        if let error = loadError {
            throw error
        }
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }
}

extension NSPersistentStoreCoordinator {
    func createCopyOfStore(at url: URL) throws {
        guard let sourceStore = persistentStores.first else {
            throw LoggerStore.Error.unknownError // Should never happen
        }

        let backupCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

        var intermediateStoreOptions = sourceStore.options ?? [:]
        intermediateStoreOptions[NSReadOnlyPersistentStoreOption] = true

        let intermediateStore = try backupCoordinator.addPersistentStore(
            ofType: sourceStore.type,
            configurationName: sourceStore.configurationName,
            at: sourceStore.url,
            options: intermediateStoreOptions
        )

        let backupStoreOptions: [AnyHashable: Any] = [
            NSReadOnlyPersistentStoreOption: true,
            // Disable write-ahead logging. Benefit: the entire store will be
            // contained in a single file. No need to handle -wal/-shm files.
            // https://developer.apple.com/library/content/qa/qa1809/_index.html
            NSSQLitePragmasOption: ["journal_mode": "OFF"],
            // Minimize file size
            NSSQLiteManualVacuumOption: true,
        ]

        try backupCoordinator.migratePersistentStore(
            intermediateStore,
            to: url,
            options: backupStoreOptions,
            withType: NSSQLiteStoreType
        )
    }
}
