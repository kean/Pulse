// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import UIKit

extension UITableView {
    func apply<T: Hashable>(diff: CollectionDifference<T>, _ closure: () -> Void) {
        var deletes: [IndexPath] = []
        var inserts: [IndexPath] = []

        for update in diff.inferringMoves() {
            switch update {
            case .remove(let offset, _, let move):
                if move == nil {
                    deletes.append(IndexPath(row: offset, section: 0))
                }
            case .insert(let offset, _, let move):
                // If there's no move, it's a true insertion and not the result of a move.
                if move == nil {
                    inserts.append(IndexPath(row: offset, section: 0))
                }
            }
        }

        performBatchUpdates {
            closure()
            insertRows(at: inserts, with: .right)
            deleteRows(at: deletes, with: .left)
        }
    }
}

#endif
