// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import PulseCore
import CoreData

final class ConsoleMessagesTextSearch {
    private(set) var messages: [LoggerMessageEntity] = []
    private var searchIndex: [(NSManagedObjectID, String)]?
    private let lock = NSLock()

    func replace(_ messages: [LoggerMessageEntity]) {
        self.messages = messages
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
        let searchIndex = messages.map { ($0.objectID, $0.text) }
        self.searchIndex = searchIndex
        return searchIndex
    }
}

#endif
