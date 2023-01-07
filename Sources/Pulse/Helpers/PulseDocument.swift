// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import CoreData

final class PulseDocument {
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init(documentURL: URL) throws {
        guard Files.fileExists(atPath: documentURL.deletingLastPathComponent().path) else {
            throw LoggerStore.Error.fileDoesntExist
        }
        self.container = NSPersistentContainer(name: documentURL.lastPathComponent, managedObjectModel: PulseDocument.model)
        let store = NSPersistentStoreDescription(url: documentURL)
        store.setValue("OFF" as NSString, forPragmaNamed: "journal_mode")
        container.persistentStoreDescriptions = [store]

        try container.loadStore()
    }

    /// Opens existing store and returns store info.
    func open() throws -> LoggerStore.Info {
        guard let info = getBlob(forKey: "info") else {
            throw LoggerStore.Error.storeInvalid
        }
        return try JSONDecoder().decode(LoggerStore.Info.self, from: info)
    }

    // Opens an existing database.
    func database() throws -> Data {
        guard let database = getBlob(forKey: "database") else {
            throw LoggerStore.Error.storeInvalid
        }
        return database
    }

    func getBlob(forKey key: String) -> Data? {
        try? context.first(PulseBlobEntity.self) {
            $0.predicate = NSPredicate(format: "key == %@", key)
        }?.data
    }

    func close() throws {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        let blob = NSEntityDescription(class: PulseBlobEntity.self)
        blob.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "data", type: .binaryDataAttributeType)
        ]
        model.entities = [blob]
        return model
    }()
}

final class PulseBlobEntity: NSManagedObject {
    @NSManaged var key: String
    @NSManaged var data: Data
}
