// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Pulse
import CoreData

@available(iOS 15, macOS 13, *)
struct ConsoleEntityCell: View {
    let entity: NSManagedObject

    var body: some View {
        switch LoggerEntity(entity) {
        case .message(let message):
            _ConsoleMessageCell(message: message)
#if os(macOS)
                .listRowSeparator(.visible)
#endif
        case .task(let task):
            _ConsoleTaskCell(task: task)
#if os(macOS)
                .listRowSeparator(.visible)
#endif
        }
    }
}

@available(iOS 15, macOS 13, *)
private struct _ConsoleMessageCell: View {
    let message: LoggerMessageEntity

    @State private var shareItems: ShareItems?

    var body: some View {
#if os(iOS)
        let cell = ConsoleMessageCell(message: message, isDisclosureNeeded: true)
            .background(NavigationLink("", destination: ConsoleMessageDetailsView(message: message)).opacity(0))
#elseif os(macOS)
        let cell = ConsoleMessageCell(message: message)
            .tag(ConsoleSelectedItem.entity(message.objectID))
#else
        // `id` is a workaround for macOS (needs to be fixed)
        let cell = NavigationLink(destination: ConsoleMessageDetailsView(message: message)) {
            ConsoleMessageCell(message: message)
        }
#endif

#if os(iOS) || os(macOS)
        cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
            PinButton(viewModel: .init(message)).tint(.pink)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: { shareItems = ShareService.share(message, as: .html) }) {
                Label("Share", systemImage: "square.and.arrow.up.fill")
            }.tint(.blue)
        }
        .contextMenu {
            ContextMenu.MessageContextMenu(message: message, shareItems: $shareItems)
        }
#if os(iOS)
        .sheet(item: $shareItems, content: ShareView.init)
#else
        .popover(item: $shareItems, attachmentAnchor: .point(.leading), arrowEdge: .leading) { ShareView($0) }
#endif
#else
        cell
#endif
    }
}

@available(iOS 15, macOS 13, *)
private struct _ConsoleTaskCell: View {
    let task: NetworkTaskEntity
    @State private var shareItems: ShareItems?
    @State private var sharedTask: NetworkTaskEntity?

    var body: some View {
#if os(iOS)
        let cell = ConsoleTaskCell(task: task, isDisclosureNeeded: true)
            .background(NavigationLink("", destination: NetworkInspectorView(task: task)).opacity(0))
#elseif os(macOS)
        let cell = ConsoleTaskCell(task: task)
            .tag(ConsoleSelectedItem.entity(task.objectID))
#else
        let cell = NavigationLink(destination: NetworkInspectorView(task: task)) {
            ConsoleTaskCell(task: task)
        }
#endif

#if os(iOS) || os(macOS)
        cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
            PinButton(viewModel: .init(task)).tint(.pink)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: {
#if os(iOS)
                shareItems = ShareService.share(task, as: .html)
#else
                sharedTask = task
#endif
            }) {
                Label("Share", systemImage: "square.and.arrow.up.fill")
            }.tint(.blue)
        }
        .contextMenu {
#if os(iOS)
            ContextMenu.NetworkTaskContextMenuItems(task: task, sharedItems: $shareItems)
#else
            ContextMenu.NetworkTaskContextMenuItems(task: task, sharedTask: $sharedTask)
#endif
        }
#if os(iOS)
        .sheet(item: $shareItems, content: ShareView.init)
#else
        .popover(item: $sharedTask, attachmentAnchor: .point(.leading), arrowEdge: .leading) { ShareNetworkTaskView(task: $0) }
#endif
#else
        cell
#endif
    }
}
