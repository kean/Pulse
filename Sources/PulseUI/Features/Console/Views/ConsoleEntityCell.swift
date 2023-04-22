// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Pulse
import CoreData

struct ConsoleEntityCell: View {
    let entity: NSManagedObject

    var body: some View {
        switch LoggerEntity(entity) {
        case .message(let message):
            _ConsoleMessageCell(message: message)
#if os(macOS)
                .backport.listRowSeparators(isHidden: false)
#endif
        case .task(let task):
            _ConsoleTaskCell(task: task)
#if os(macOS)
                .backport.listRowSeparators(isHidden: false)
#endif
        }
    }
}

private struct _ConsoleMessageCell: View {
    let message: LoggerMessageEntity
    @State private var shareItems: ShareItems?

    var body: some View {
#if os(iOS)
        let cell = ConsoleMessageCell(viewModel: .init(message: message), isDisclosureNeeded: true)
            .background(NavigationLink("", destination: ConsoleMessageDetailsView(message: message)).opacity(0))
#elseif os(macOS)
        let cell = ConsoleMessageCell(viewModel: .init(message: message))
            .tag(ConsoleSelectedItem.entity(message.objectID))
#else
        // `id` is a workaround for macOS (needs to be fixed)
        let cell = NavigationLink(destination: ConsoleMessageDetailsView(message: message)) {
            ConsoleMessageCell(viewModel: .init(message: message))
        }
#endif

#if os(iOS) || os(macOS)
        if #available(iOS 15, *) {
            cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
                PinButton(viewModel: .init(message)).tint(.pink)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(action: { shareItems = ShareService.share(message, as: .html) }) {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }.tint(.blue)
            }
            .backport.contextMenu(menuItems: {
                Section {
                    Button(action: { shareItems = ShareService.share(message, as: .plainText) }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }.tint(.blue)
                    Button(action: { UXPasteboard.general.string = message.text }) {
                        Label("Copy Message", systemImage: "doc.on.doc")
                    }.tint(.blue)
                }
                Section {
                    PinButton(viewModel: .init(message)).tint(.pink)
                }
            }, preview: {
                ConsoleMessageCellPreview(message: message)
                    .frame(idealWidth: 320, maxHeight: 600)
            })
#if os(iOS)
            .sheet(item: $shareItems, content: ShareView.init)
#else
            .popover(item: $shareItems, attachmentAnchor: .point(.leading), arrowEdge: .leading) { ShareView($0) }
#endif
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
    @State private var isSharing = false

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
        if #available(iOS 15, *) {
            cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
                PinButton(viewModel: .init(task)).tint(.pink)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(action: {
#if os(iOS)
                    shareItems = ShareService.share(task, as: .html)
#else
                    isSharing = true
#endif
                }) {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }.tint(.blue)
            }
            .backport.contextMenu(menuItems: {
#if os(iOS)
                ContextMenu.NetworkTaskContextMenuItems(task: task, sharedItems: $shareItems)
#else
                ContextMenu.NetworkTaskContextMenuItems(task: task, isSharing: $isSharing)
#endif
            }, preview: {
                ConsoleTaskCellPreview(task: task)
                    .frame(idealWidth: 320, maxHeight: 600)
            })
#if os(iOS)
            .sheet(item: $shareItems, content: ShareView.init)
#else
            .popover(isPresented: $isSharing, attachmentAnchor: .point(.leading), arrowEdge: .leading) { ShareNetworkTaskView(task: task) }
#endif
        } else {
            cell
        }
#else
        cell
#endif
    }
}

#if os(iOS) || os(macOS)
@available(iOS 15, tvOS 15, *)
private struct ConsoleMessageCellPreview: View {
    let message: LoggerMessageEntity

    var body: some View {
        TextViewPreview(string: TextRenderer(options: .sharing).make {
            $0.render(message)
        })
    }
}

@available(iOS 15, tvOS 15, *)
private struct ConsoleTaskCellPreview: View {
    let task: NetworkTaskEntity

    var body: some View {
        TextViewPreview(string: TextRenderer(options: .sharing).make {
            $0.render(task, content: .preview)
        })
    }
}

@available(iOS 15, tvOS 15, *)
private struct TextViewPreview: View {
    let string: NSAttributedString

    var body: some View {
        let range = NSRange(location: 0, length: min(2000, string.length))
#if os(iOS)
        let attributedString = try? AttributedString(string.attributedSubstring(from: range), including: \.uiKit)
#else
        let attributedString = try? AttributedString(string.attributedSubstring(from: range), including: \.appKit)
#endif
        Text(attributedString ?? AttributedString("–"))
            .padding(12)
    }
}
#endif
