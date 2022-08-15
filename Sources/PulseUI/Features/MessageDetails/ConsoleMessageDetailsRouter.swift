// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse

struct ConsoleMessageDetailsRouter: View {
    @ObservedObject var viewModel: ConsoleDetailsRouterViewModel

    var body: some View {
        if let viewModel = viewModel.viewModel {
            switch viewModel {
            case .message(let viewModel):
                ConsoleMessageDetailsView(viewModel: viewModel, onClose: onClose)
                    .id(self.viewModel.id)
            case .task(let viewModel):
                // TODO: rework the inspector to not require id workaround
                NetworkInspectorView(viewModel: viewModel, onClose: onClose)
                    .id(self.viewModel.id)
            }
        }
    }

    private func onClose() {
        viewModel.select(nil)
    }
}

final class ConsoleDetailsRouterViewModel: ObservableObject {
    @Published private(set) var viewModel: DetailsViewModel?
    var id: NSManagedObjectID?

    func select(_ entity: NSManagedObject?) {
        self.id = entity?.objectID
        if let message = entity as? LoggerMessageEntity {
            if let task = message.task {
                viewModel = .task(.init(task: task))
            } else {
                viewModel = .message(.init(message: message))
            }
        } else if let task = entity as? NetworkTaskEntity {
            viewModel = .task(.init(task: task))
        } else {
            viewModel = nil
        }
    }

    enum DetailsViewModel {
        case message(ConsoleMessageDetailsViewModel)
        case task(NetworkInspectorViewModel)
    }
}
