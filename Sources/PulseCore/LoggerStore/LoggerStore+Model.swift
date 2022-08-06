// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData

extension LoggerStore {
    /// Returns Core Data model used by the store.
    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let message = NSEntityDescription(name: "LoggerMessageEntity", class: LoggerMessageEntity.self)
        let metadata = NSEntityDescription(name: "LoggerMetadataEntity", class: LoggerMetadataEntity.self)
        let request = NSEntityDescription(name: "LoggerNetworkRequestEntity", class: LoggerNetworkRequestEntity.self)
        let requestProgress = NSEntityDescription(name: "LoggerNetworkRequestProgressEntity", class: LoggerNetworkRequestProgressEntity.self)
        let blob = NSEntityDescription(name: "LoggerBlobHandleEntity", class: LoggerBlobHandleEntity.self)
        let inlinedData = NSEntityDescription(name: "LoggerInlineDataEntity", class: LoggerInlineDataEntity.self)

        message.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "isPinned", type: .booleanAttributeType),
            NSAttributeDescription(name: "session", type: .UUIDAttributeType),
            NSAttributeDescription(name: "level", type: .integer16AttributeType),
            NSAttributeDescription(name: "label", type: .stringAttributeType),
            NSAttributeDescription(name: "text", type: .stringAttributeType),
            NSRelationshipDescription.make(name: "metadata", type: .oneToMany, entity: metadata),
            NSAttributeDescription(name: "file", type: .stringAttributeType),
            NSAttributeDescription(name: "function", type: .stringAttributeType),
            NSAttributeDescription(name: "line", type: .integer32AttributeType),
            NSRelationshipDescription.make(name: "request", type: .oneToOne(isOptional: true), entity: request)
        ]

        metadata.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "value", type: .stringAttributeType)
        ]

        request.properties = [
            NSAttributeDescription(name: "createdAt", type: .dateAttributeType),
            NSAttributeDescription(name: "isPinned", type: .booleanAttributeType),
            NSAttributeDescription(name: "session", type: .UUIDAttributeType),
            NSAttributeDescription(name: "taskId", type: .UUIDAttributeType),
            NSAttributeDescription(name: "rawTaskType", type: .integer16AttributeType),
            NSAttributeDescription(name: "url", type: .stringAttributeType),
            NSAttributeDescription(name: "host", type: .stringAttributeType),
            NSAttributeDescription(name: "httpMethod", type: .stringAttributeType),
            NSAttributeDescription(name: "errorDomain", type: .stringAttributeType),
            NSAttributeDescription(name: "errorCode", type: .integer32AttributeType),
            NSAttributeDescription(name: "statusCode", type: .integer32AttributeType),
            NSAttributeDescription(name: "startDate", type: .dateAttributeType),
            NSAttributeDescription(name: "duration", type: .doubleAttributeType),
            NSAttributeDescription(name: "responseContentType", type: .stringAttributeType),
            NSAttributeDescription(name: "requestState", type: .integer16AttributeType),
            NSAttributeDescription(name: "redirectCount", type: .integer16AttributeType),
            NSAttributeDescription(name: "requestBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "responseBodySize", type: .integer64AttributeType),
            NSAttributeDescription(name: "isFromCache", type: .booleanAttributeType),
            NSRelationshipDescription.make(name: "message", type: .oneToOne(), entity: message),
            NSRelationshipDescription.make(name: "detailsData", type: .oneToOne(), entity: inlinedData),
            NSRelationshipDescription.make(name: "requestBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            NSRelationshipDescription.make(name: "responseBody", type: .oneToOne(isOptional: true), deleteRule: .noActionDeleteRule, entity: blob),
            NSRelationshipDescription.make(name: "progress", type: .oneToOne(isOptional: true), entity: requestProgress)
        ]

        requestProgress.properties = [
            NSAttributeDescription(name: "completedUnitCount", type: .integer64AttributeType),
            NSAttributeDescription(name: "totalUnitCount", type: .integer64AttributeType)
        ]

        blob.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "size", type: .integer64AttributeType),
            NSAttributeDescription(name: "decompressedSize", type: .integer64AttributeType),
            NSAttributeDescription(name: "linkCount", type: .integer16AttributeType),
            NSRelationshipDescription.make(name: "inlineData", type: .oneToOne(isOptional: true), entity: inlinedData)
        ]

        inlinedData.properties = [
            NSAttributeDescription(name: "data", type: .binaryDataAttributeType)
        ]

        model.entities = [message, metadata, request, requestProgress, blob, inlinedData]
        return model
    }()

    static let archiveModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let archive = NSEntityDescription(name: "PulseDocumentEntity", class: PulseDocumentEntity.self)
        let blob = NSEntityDescription(name: "PulseBlobEntity", class: PulseBlobEntity.self)

        archive.properties = [
            NSAttributeDescription(name: "info", type: .binaryDataAttributeType),
            NSAttributeDescription(name: "database", type: .binaryDataAttributeType),
            NSRelationshipDescription.make(name: "blobs", type: .oneToMany, entity: blob)
        ]

        blob.properties = [
            NSAttributeDescription(name: "key", type: .stringAttributeType),
            NSAttributeDescription(name: "data", type: .binaryDataAttributeType)
        ]

        model.entities = [archive, blob]

        return model
    }()
}

final class PulseDocumentEntity: NSManagedObject {
    @NSManaged var info: Data
    @NSManaged var database: Data
    @NSManaged var blobs: Set<PulseBlobEntity>
}

final class PulseBlobEntity: NSManagedObject {
    @NSManaged var key: String
    @NSManaged var data: Data
}

final class PulseDocument {
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    private func document() throws -> PulseDocumentEntity {
        guard let document = self._document else {
            throw LoggerStore.Error.unknownError // Programmatic error
        }
        return document
    }

    private var _document: PulseDocumentEntity?

    init(documentURL: URL) throws {
        #warning("move archive model jer")
        self.container = NSPersistentContainer(name: documentURL.lastPathComponent, managedObjectModel: LoggerStore.archiveModel)
        let store = NSPersistentStoreDescription(url: documentURL)
        store.setValue("NONE" as NSString, forPragmaNamed: "journal_mode")
        store.setOption(true as NSNumber, forKey: NSSQLiteManualVacuumOption)
        container.persistentStoreDescriptions = [store]

        try container.loadStore()
    }

    /// Opens existing store and returns store info.
    func open() throws -> LoggerStore.Info {
        guard let document = try context.first(PulseDocumentEntity.self) else {
            throw LoggerStore.Error.storeInvalid
        }
        self._document = document
        return try JSONDecoder().decode(LoggerStore.Info.self, from: document.info)
    }

    // Opens an existing database.
    func database() throws -> Data {
        try document().database.decompressed()
    }

    func getBlob(forKey key: String) -> Data? {
        try? context.first(LoggerBlobHandleEntity.self) {
            $0.predicate = NSPredicate(format: "key == %@", key)
        }?.data
    }

    func close() throws {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }
}

// MARK: - Helpers

private extension NSEntityDescription {
    convenience init<T>(name: String, class: T.Type) where T: NSManagedObject {
        self.init()
        self.name = name
        self.managedObjectClassName = T.self.description()
    }
}

private extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType, _ configure: (NSAttributeDescription) -> Void = { _ in }) {
        self.init()
        self.name = name
        self.attributeType = type
        configure(self)
    }
}

private enum RelationshipType {
    case oneToMany
    case oneToOne(isOptional: Bool = false)
}

private extension NSRelationshipDescription {
    static func make(name: String,
                     type: RelationshipType,
                     deleteRule: NSDeleteRule = .cascadeDeleteRule,
                     entity: NSEntityDescription) -> NSRelationshipDescription {
        let relationship = NSRelationshipDescription()
        relationship.name = name
        relationship.deleteRule = deleteRule
        relationship.destinationEntity = entity
        switch type {
        case .oneToMany:
            relationship.maxCount = 0
            relationship.minCount = 0
        case .oneToOne(let isOptional):
            relationship.maxCount = 1
            relationship.minCount = isOptional ? 0 : 1
        }
        return relationship
    }
}
