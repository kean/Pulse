// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Pulse
import CoreData

#warning("add context menus back")
#warning("inject viewmodels here & impement focus actions for messages")

struct ConsoleEntityCell: View {
    let entity: NSManagedObject

    var body: some View {
        if let task = entity as? NetworkTaskEntity {
            _ConsoleTaskCell(task: task)
        } else if let message = entity as? LoggerMessageEntity {
            if let task = message.task {
                _ConsoleTaskCell(task: task)
            } else {
                _ConsoleMessageCell(message: message)
            }
        } else {
            fatalError("Unsupported entity: \(entity)")
        }
    }
}

private struct _ConsoleMessageCell: View {
    let message: LoggerMessageEntity
    @State private var shareItems: ShareItems?

    var body: some View {
        let cell = NavigationLink(destination: LazyConsoleDetailsView(message: message).id(message.objectID)) {
            ConsoleMessageCell(viewModel: .init(message: message))
        }
#if os(iOS)
        if #available(iOS 15, *) {
            cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
                PinButton(viewModel: .init(message)).tint(.pink)
            }.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(action: { shareItems = ShareService.share(message, as: .html) }) {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }.tint(.blue)
            }.sheet(item: $shareItems, content: ShareView.init)
        } else {
            cell
        }
#else
        cell
#endif
    }
}

private struct _ConsoleTaskCell: View {
    let task: NetworkTaskEntity
    @State private var shareItems: ShareItems?

    var body: some View {
        let cell = NavigationLink(destination: LazyNetworkInspectorView(task: task).id(task.objectID)) {
            ConsoleTaskCell(viewModel: .init(task: task))
        }
#if os(iOS)
        if #available(iOS 15, *) {
            cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
                PinButton(viewModel: .init(task)).tint(.pink)
            }.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(action: { shareItems = ShareService.share(task, as: .html) }) {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }.tint(.blue)
            }.sheet(item: $shareItems, content: ShareView.init)
        } else {
            cell
        }
#else
        cell
#endif
    }
}

// Create the underlying ViewModel lazily.
private struct LazyNetworkInspectorView: View {
    let task: NetworkTaskEntity

    var body: some View {
        NetworkInspectorView(viewModel: .init(task: task))
    }
}

// Create the underlying ViewModel lazily.
private struct LazyConsoleDetailsView: View {
    let message: LoggerMessageEntity

    var body: some View {
        ConsoleMessageDetailsView(viewModel: .init(message: message))
    }
}
