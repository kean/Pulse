// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import SwiftUI
import Pulse
import CoreData

@available(iOS 15, macOS 13, *)
struct ConsoleEntityDetailsRouterView: View {
    let selection: ConsoleSelectedItem

    @Environment(\.router) private var router
    @Environment(\.store) private var store

    var body: some View {
        switch selection {
        case .entity(let objectID):
            makeDetails(for: objectID)
        case .occurrence(let objectID, let occurrence):
            if let entity = entity(withID: objectID) {
                ConsoleSearchResultView.makeDestination(for: occurrence, entity: entity)
                    .id(occurrence.id)
            }
        }
    }

    @ViewBuilder
    private func makeDetails(for objectID: NSManagedObjectID) -> some View {
        if let entity = entity(withID: objectID) {
            switch LoggerEntity(entity) {
            case .message(let message):
                ConsoleMessageDetailsView(message: message)
            case .task(let task):
                NetworkInspectorView(task: task)
            }
        }
    }

    private func entity(withID objectID: NSManagedObjectID) -> NSManagedObject? {
        try? store.viewContext.existingObject(with: objectID)
    }
}

struct ButtonCloseDetailsView: View {
    @Environment(\.router) private var router

    var body: some View {
        Button(action: { router.selection = nil }) {
            Image(systemName: "xmark")
                .foregroundColor(.secondary)
        }.buttonStyle(.plain)
    }
}

struct ConsoleEntityStandaloneDetailsView: View {
    let entity: NSManagedObject

    var body: some View {
        switch LoggerEntity(entity) {
        case .message(let message):
            ConsoleMessageDetailsView(message: message)
        case .task(let task):
            NetworkInspectorView(task: task)
        }
    }
}

#endif
