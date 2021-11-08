// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

func descriptionForStatusCode(_ statusCode: Int) -> String {
    switch statusCode {
    case 200: return "200 (OK)"
    default: return "\(statusCode) (\( HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized))"
    }
}

var Files: FileManager { FileManager.default }

extension FileManager {
    @discardableResult
    func createDirectoryIfNeeded(at url: URL) -> Bool {
        guard !fileExists(atPath: url.path) else { return false }
        try? createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
        return true
    }
}

extension URL {
    static var temp: URL {
        let url = Files.temporaryDirectory
            .appendingDirectory("com.github.kean.logger")
        Files.createDirectoryIfNeeded(at: url)
        return url
    }

    static var logs: URL {
        var url = Files.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingDirectory("Logs")
            .appendingDirectory("com.github.kean.logger")  ?? URL(fileURLWithPath: "/dev/null")
        if !Files.createDirectoryIfNeeded(at: url) {
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
        return url
    }

    func appendingFilename(_ filename: String) -> URL {
        appendingPathComponent(filename, isDirectory: false)
    }

    func appendingDirectory(_ directory: String) -> URL {
        appendingPathComponent(directory, isDirectory: true)
    }
}

// MARK: - CoreData

extension NSPersistentStoreCoordinator {
    func createCopyOfStore(at url: URL) throws {
        guard let sourceStore = persistentStores.first else {
            throw LoggerStoreError.unknownError // Should never happen
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
            NSSQLitePragmasOption: ["journal_mode": "DELETE"],
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

extension NSManagedObjectContext {
    func tryPerform<T>(_ closure: () throws -> T) throws -> T {
        var result: Result<T, Error>?
        performAndWait {
            result = Result { try closure() }
        }
        guard let unwrappedResult = result else { throw LoggerStoreError.unknownError }
        return try unwrappedResult.get()
    }
}
