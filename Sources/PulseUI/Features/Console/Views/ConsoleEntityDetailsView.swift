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
                    ConsoleEntityDetailsView.makeDestination(for: occurence, entity: entity)
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

    @ViewBuilder
    static func makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        _makeDestination(for: occurrence, entity: entity)
            .environment(\.textViewSearchContext, occurrence.searchContext)
    }

    @ViewBuilder
    private static func _makeDestination(for occurrence: ConsoleSearchOccurrence, entity: NSManagedObject) -> some View {
        if let message = entity as? LoggerMessageEntity {
            if let task = message.task {
                _makeDestination(for: occurrence, task: task)
            } else {
#if os(macOS)
                ConsoleMessageDetailsView(message: message, onClose: {})
#else
                ConsoleMessageDetailsView(message: message)
#endif
            }
        } else if let task = entity as? NetworkTaskEntity {
            _makeDestination(for: occurrence, task: task)
        } else {
            fatalError("Unsupported entity: \(entity)")
        }
    }

    @ViewBuilder
    private static func _makeDestination(for occurrence: ConsoleSearchOccurrence, task: NetworkTaskEntity) -> some View {
        switch occurrence.scope {
        case .url:
            NetworkDetailsView(title: "URL") {
                TextRenderer(options: .sharing).make {
                    $0.render(task, content: .requestComponents)
                }
            }
        case .originalRequestHeaders:
            makeHeadersDetails(title: "Request Headers", headers: task.originalRequest?.headers)
        case .currentRequestHeaders:
            makeHeadersDetails(title: "Request Headers", headers: task.currentRequest?.headers)
        case .requestBody:
            NetworkInspectorRequestBodyView(viewModel: .init(task: task))
        case .responseHeaders:
            makeHeadersDetails(title: "Response Headers", headers: task.response?.headers)
        case .responseBody:
            NetworkInspectorResponseBodyView(viewModel: .init(task: task))
        case .message, .metadata:
            EmptyView()
        }
    }

    private static func makeHeadersDetails(title: String, headers: [String: String]?) -> some View {
        NetworkDetailsView(title: title) {
            KeyValueSectionViewModel.makeHeaders(title: title, headers: headers)
        }
    }
}

#endif
