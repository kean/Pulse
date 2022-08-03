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
}
