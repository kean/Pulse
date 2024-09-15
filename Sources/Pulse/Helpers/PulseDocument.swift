// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import CoreData

package final class PulseDocument {
    package let container: NSPersistentContainer
    package var context: NSManagedObjectContext { container.viewContext }

    package init(documentURL: URL) throws {
        guard Files.fileExists(atPath: documentURL.deletingLastPathComponent().path) else {
            throw LoggerStore.Error.fileDoesntExist
        }
        self.container = NSPersistentContainer(name: documentURL.lastPathComponent, managedObjectModel: PulseDocument.model)
        let store = NSPersistentStoreDescription(url: documentURL)
        store.setValue("OFF" as NSString, forPragmaNamed: "journal_mode")
        container.persistentStoreDescriptions = [store]

        try container.loadStore()
    }

    package func close() throws {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    /// - warning: Model has to be loaded only once.
    nonisolated(unsafe) static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()
        let blob = NSEntityDescription(class: PulseBlobEntity.self)
        blob.properties = [
            NSAttributeDescription("key", .stringAttributeType),
            NSAttributeDescription("data", .binaryDataAttributeType)
        ]
        model.entities = [blob]
        return model
    }()
}

package final class PulseBlobEntity: NSManagedObject {
    @NSManaged package var key: String
    @NSManaged package var data: Data
}
