// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import PulseCore
import CoreData
import Combine
import AppKit

final class NotListViewModel<Element: NotListIdentifiable>: ObservableObject {
    var elements = [Element]() {
        didSet { actuallyNeedsReload = true }
    }

    var actuallyNeedsReload = false {
        didSet { if actuallyNeedsReload { objectWillChange.send() } }
    }

    var scrollToIndex: Int? {
        didSet { if scrollToIndex != nil { objectWillChange.send() } }
    }

    var isVisibleOnlyReloadNeeded = false {
        didSet { if isVisibleOnlyReloadNeeded { objectWillChange.send() } }
    }
}

// Because SwiftUI List is pretty broken on macOS https://kean.blog/post/not-list
struct NotList<Element: NotListIdentifiable>: NSViewRepresentable {
    @ObservedObject var model: NotListViewModel<Element>

    let makeRowView: (Element, NSTableView) -> NSView?
    let onSelectRow: (Int) -> Void
    let onDoubleClickRow: (Int) -> Void
    var isEmphasizedRow: ((Int) -> Bool) = { _ in true }

    final class Coordinator: NSObject, NSTableViewDelegate, NSTableViewDataSource {
        private let list: NotList
        private var model: NotListViewModel<Element> { list.model }

        init(view: NotList) {
            self.list = view
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            model.elements.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let message = model.elements[row]
            let view = list.makeRowView(message, tableView)
            view?.alphaValue = list.isEmphasizedRow(row) ? 1 : 0.33
            return view
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            50
        }

        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
            list.onSelectRow(row)
            return true
        }

        @objc func tableViewDoubleClick(_ tableView: NSTableView) {
            list.onDoubleClickRow(tableView.clickedRow)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(view: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.addTableColumn(.init(identifier: .init(rawValue: "a")))
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.tableViewDoubleClick(_:))

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let tableView = (nsView.documentView as! NSTableView)

        if model.actuallyNeedsReload {
            model.actuallyNeedsReload = false

            let selectedMessageID = (tableView.selectedRow == -1 || model.elements.count <= tableView.selectedRow) ? nil : model.elements[tableView.selectedRow].id
            tableView.reloadData()

            // Restore selection
            if let selectedObjectID = selectedMessageID {
                let range = tableView.rows(in: tableView.visibleRect)
                for index in range.lowerBound..<range.upperBound {
                    if model.elements[index].id == selectedObjectID {
                        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                        break
                    }
                }
            }
        }

        if let index = model.scrollToIndex {
            model.scrollToIndex = nil

            tableView.scrollRowToVisible(index)
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }

        if model.isVisibleOnlyReloadNeeded {
            model.isVisibleOnlyReloadNeeded = false

            for index in 0..<model.elements.count {
                if let row = tableView.rowView(atRow: index, makeIfNecessary: false) {
                    let alpha: CGFloat = isEmphasizedRow(index) ? 1 : 0.33
                    if let subview = row.subviews.last, subview.alphaValue != alpha {
                        subview.alphaValue = alpha
                    }
                }
            }
        }
    }
}

protocol NotListIdentifiable {
    associatedtype ID: Hashable
    var id: ID { get }
}

extension NSManagedObject: NotListIdentifiable {
    public var id: NSManagedObjectID { objectID }
}

#endif
