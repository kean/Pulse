// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import Foundation

package struct ConsoleListPredicateOptions: @unchecked Sendable {
    package var filters = ConsoleFilters()
    package var sessions: Set<UUID> = []
    package var isOnlyErrors = false
    package var predicate: NSPredicate?
    package var focus: NSPredicate?

    package init() {}
}
