// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(visionOS)

import Foundation
import CoreData
import Pulse

package final class ConsoleSearchService: @unchecked Sendable {
    private let cache = NSCache<NSManagedObjectID, CachedString>()

    package init() {
        cache.totalCostLimit = 16_000_000
        cache.countLimit = 1000
    }

    package func clearCache() {
        cache.removeAllObjects()
    }

    package func getBodyString(for blob: LoggerBlobHandleEntity) -> String? {
        if let string = cache.object(forKey: blob.objectID)?.value {
            return string
        }
        guard let data = blob.data, let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        cache.setObject(.init(value: string), forKey: blob.objectID, cost: data.count)
        return string
    }
}

/// Wrapping it in a class to make it compatible with `NSCache`.
private final class CachedString {
    let value: String
    init(value: String) { self.value = value }
}

#endif
