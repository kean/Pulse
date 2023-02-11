// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import SwiftUI
import Pulse
import CoreData

struct ConsoleEntityDetailsView: View {
    let store: LoggerStore
    @ObservedObject var router: ConsoleRouter
    @Binding var isVertical: Bool

    var body: some View {
        if let selection = router.selection {
            switch selection {
            case .entity(let objectID):
                makeDetails(for: objectID)
            case .occurence(let objectID, let occurence):
                if let entity = entity(withID: objectID) {
                    ConsoleSearchResultView.makeDestination(for: occurence, entity: entity)
                        .id(occurence.id)
                }
            }
        }
    }

    @ViewBuilder
    private func makeDetails(for objectID: NSManagedObjectID) -> some View {
        if let entity = entity(withID: objectID) {
            switch LoggerEntity(entity) {
            case .message(let message):
                ConsoleMessageDetailsView(message: message, toolbarItems: AnyView(toolbarItems))
            case .task(let task):
                NetworkInspectorView(task: task, toolbarItems: AnyView(toolbarItems))
            }
        }
    }

    @ViewBuilder
    var toolbarItems: some View {
        Button(action: { isVertical.toggle() }, label: {
            Image(systemName: isVertical ? "square.split.2x1" : "square.split.1x2")
                .foregroundColor(.secondary)
        })
        .help(isVertical ? "Switch to Horizontal Layout" : "Switch to Vertical Layout")
        .buttonStyle(.plain)

        Button(action: { router.selection = nil }) {
            Image(systemName: "xmark")
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    private func entity(withID objectID: NSManagedObjectID) -> NSManagedObject? {
        try? store.viewContext.existingObject(with: objectID)
    }
}

#endif
