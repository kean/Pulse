// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import CoreData

final class FetchedObjects<Element: NSManagedObject>: RandomAccessCollection {
    typealias Index = Int

    private let controller: NSFetchedResultsController<Element>

    init(controller: NSFetchedResultsController<Element>) {
        self.controller = controller
    }

    var count: Int {
        controller.sections?.first?.numberOfObjects ?? 0
    }

    var startIndex: Int { 0 }
    var endIndex: Int { count }

    var isEmpty: Bool {
        count == 0
    }

    var indices: Range<Int> {
        startIndex..<endIndex
    }

    var first: Element? {
        guard !isEmpty else { return nil }
        return self[0]
    }

    subscript(index: Int) -> Element {
        controller.object(at: IndexPath(item: index, section: 0))
    }

    func index(after i: Int) -> Int {
        i + 1
    }
}

enum FetchedObjectsUpdate {
    case append(range: Range<Int>)
    case reload
}

struct ConsoleMatch {
    let index: Int
    let objectID: NSManagedObjectID
}
