// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import Pulse
import CoreData

final class ManagedObjectTextSearch<T: NSManagedObject> {
    private(set) var objects: AnyCollection<T> = AnyCollection([])
    private var searchIndex: [(NSManagedObjectID, String)]?
    private let closure: (T) -> String
    private let lock = NSLock()

    init(_ closure: @escaping (T) -> String) {
        self.closure = closure
    }

    func replace<S: Collection>(_ objects: S) where S.Element == T {
        self.objects = AnyCollection(objects)
        self.searchIndex = nil
    }

    func search(term: String, options: StringSearchOptions) -> [ConsoleMatch] {
        let searchIndex = getSearchIndex()
        let indices = searchIndex.indices
        let iterations = indices.count > 100 ? 8 : 1
        var allMatches: [[Int]] = Array(repeating: [], count: iterations)
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            let start = index * indices.count / iterations
            let end = (index + 1) * indices.count / iterations

            var matches = [Int]()
            for matchIndex in start..<end {
                let messageIndex = indices[matchIndex]
                if searchIndex[messageIndex].1.range(of: term, options: .init(options), range: nil, locale: nil) != nil {
                    matches.append(messageIndex)
                }
            }

            lock.lock()
            allMatches[index] = matches
            lock.unlock()
        }
        return allMatches.flatMap { $0 }.map { ConsoleMatch(index: $0, objectID: searchIndex[$0].0) }
    }

    // It's needed for two reasons:
    // - Making sure `concurrentPerform` accesses data in a thread-safe way
    // - It's faster than accessing Core Data backed array (for some reason)
    private func getSearchIndex() -> [(NSManagedObjectID, String)] {
        if let searchIndex = self.searchIndex {
            return searchIndex
        }
        let searchIndex = objects.map { ($0.objectID, closure($0)) }
        self.searchIndex = searchIndex
        return searchIndex
    }
}

#endif
