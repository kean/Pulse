// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

package protocol LoggerStoreProtocol: AnyObject {
    var storeURL: URL { get }
    var version: LoggerStore.Version { get }
    var container: NSPersistentContainer { get }
    var backgroundContext: NSManagedObjectContext { get }

    /// Creates a new background context with the `LoggerBlogDataStore` user info
    /// key set up so that `LoggerBlobHandleEntity.data` works on the context.
    func newBackgroundContext() -> NSManagedObjectContext

    /// The ID of the current (active) session, if applicable.
    var currentSessionID: UUID? { get }
    /// Whether the store is read-only.
    var isReadonly: Bool { get }

    func info() async throws -> LoggerStore.Info
    func performChanges(_ changes: @escaping (NSManagedObjectContext) -> Void)
    func removeAll()
    func removeSessions(withIDs sessionIDs: Set<UUID>)
    func clearSessions(withIDs sessionIDs: Set<UUID>)
}

extension LoggerStoreProtocol {
    package var viewContext: NSManagedObjectContext { container.viewContext }
    package var currentSessionID: UUID? { nil }
    package var isReadonly: Bool { true }
    package func removeAll() {}
    package func removeSessions(withIDs sessionIDs: Set<UUID>) {}
    package func clearSessions(withIDs sessionIDs: Set<UUID>) {}
}

extension LoggerStore: LoggerStoreProtocol {
    package var currentSessionID: UUID? { session.id }
    package var isReadonly: Bool { options.contains(.readonly) }

    package func performChanges(_ changes: @escaping (NSManagedObjectContext) -> Void) {
        perform(changes)
    }
}
