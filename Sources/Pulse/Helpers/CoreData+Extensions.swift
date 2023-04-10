// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

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
        guard let result = result else { throw LoggerStore.Error.unknownError }
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

        let intermediateStore = try backupCoordinator.addPersistentStore(
            ofType: sourceStore.type,
            configurationName: sourceStore.configurationName,
            at: sourceStore.url,
            options: sourceStore.options ?? [:]
        )

        let backupStoreOptions: [AnyHashable: Any] = [
            // Disable write-ahead logging. Benefit: the entire store will be
            // contained in a single file. No need to handle -wal/-shm files.
            // https://developer.apple.com/library/content/qa/qa1809/_index.html
             NSSQLitePragmasOption: ["journal_mode": "OFF"]
        ]

        try backupCoordinator.migratePersistentStore(intermediateStore, to: url, options: backupStoreOptions, withType: NSSQLiteStoreType)
    }
}

extension NSEntityDescription {
    convenience init<T>(class customClass: T.Type) where T: NSManagedObject {
        self.init()
        self.name = String(describing: customClass) // e.g. `LoggerMessageEntity`
        self.managedObjectClassName = T.self.description() // e.g. `Pulse.LoggerMessageEntity`
    }
}

extension NSAttributeDescription {
    convenience init(name: String, type: NSAttributeType, _ configure: (NSAttributeDescription) -> Void = { _ in }) {
        self.init()
        self.name = name
        self.attributeType = type
        configure(self)
    }
}

enum RelationshipType {
    case oneToMany
    case oneToOne(isOptional: Bool = false)
}

extension NSRelationshipDescription {
    convenience init(name: String,
                     type: RelationshipType,
                     deleteRule: NSDeleteRule = .cascadeDeleteRule,
                     entity: NSEntityDescription) {
        self.init()
        self.name = name
        self.deleteRule = deleteRule
        self.destinationEntity = entity
        switch type {
        case .oneToMany:
            self.maxCount = 0
            self.minCount = 0
        case .oneToOne(let isOptional):
            self.maxCount = 1
            self.minCount = isOptional ? 0 : 1
        }
    }
}

enum KeyValueEncoding {
    static func encodeKeyValuePairs(_ pairs: [String: String]?, sanitize: Bool = false) -> String {
        var output = ""
        let sorted = (pairs ?? [:]).sorted { $0.key < $1.key }
        for (name, value) in sorted {
            if !output.isEmpty { output.append("\n")}
            let name = sanitize ? name.replacingOccurrences(of: ":", with: "") : name
            let value = sanitize ? String(value.filter { !$0.isWhitespace }) : value
            output.append("\(name): \(value)")
        }
        return output
    }

    static func decodeKeyValuePairs(_ string: String) -> [String: String] {
        let pairs = string.components(separatedBy: "\n")
        var output: [String: String] = [:]
        for pair in pairs {
            if let separatorIndex = pair.firstIndex(of: ":") {
                let valueStartIndex = pair.index(separatorIndex, offsetBy: 2)
                if pair.indices.contains(valueStartIndex) {
                    output[String(pair[..<separatorIndex])] = String(pair[valueStartIndex...])
                }
            }
        }
        return output
    }
}
