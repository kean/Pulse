// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import AppKit

extension NSTableView {
    func apply<T: Hashable>(diff: CollectionDifference<T>) {
        var deletes = IndexSet()
        var inserts = IndexSet()
        var moves: [(from: Int, to: Int)] = []

        for update in diff.inferringMoves() {
            switch update {
            case .remove(let offset, _, let move):
                if let move = move {
                    moves.append((offset, move))
                } else {
                    deletes.insert(offset)
                }
            case .insert(let offset, _, let move):
                if move == nil {
                    inserts.insert(offset)
                }
            }
        }

        NSAnimationContext.runAnimationGroup { context in
            if visibleRect.origin.y > 0 {
                context.duration = 0
            }

            let oldScrollOffset = visibleRect.origin
            let previousHeight = bounds.size.height
            beginUpdates()
            if !deletes.isEmpty {
                removeRows(at: deletes, withAnimation: .slideLeft)
            }
            if !inserts.isEmpty {
                insertRows(at: inserts, withAnimation: .effectGap)
            }
            endUpdates()
            var newScrollOffset = oldScrollOffset
            newScrollOffset.y += (bounds.size.height - previousHeight)

            if oldScrollOffset.y == 0 {
                scroll(oldScrollOffset)
            } else if newScrollOffset.y > oldScrollOffset.y {
                scroll(newScrollOffset)
            }
        }
    }
}

#endif
