// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import Foundation
import SwiftUI
import Pulse
import CoreData

struct ConsoleEntityDetailsView: View {
    let viewModel: ConsoleListViewModel
    @ObservedObject var router: ConsoleRouter

    var body: some View {
        if let selection = router.selection {
            switch selection {
            case .entity(let objectID):
                makeDetails(for: objectID)
            case .occurence(let objectID, let occurence):
                if let entity = viewModel.entity(withID: objectID) {
                    ConsoleSearchResultView.makeDestination(for: occurence, entity: entity)
                }
            }
        }
    }

    @ViewBuilder
    private func makeDetails(for objectID: NSManagedObjectID) -> some View {
        if let entity = viewModel.entity(withID: objectID) {
            if let task = entity as? NetworkTaskEntity {
                NetworkInspectorView(task: task, onClose: { router.selection = nil })
            } else if let message = entity as? LoggerMessageEntity {
                if let task = message.task {
                    NetworkInspectorView(task: task, onClose: { router.selection = nil })
                } else {
                    ConsoleMessageDetailsView(message: message, onClose: { router.selection = nil })
                }
            }
        }
    }


}

#endif
