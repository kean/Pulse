// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore

struct ConsoleMessageDetailsRouter: View {
    @ObservedObject var viewModel: ConsoleDetailsRouterViewModel

    var body: some View {
        if let viewModel = viewModel.viewModel {
            switch viewModel {
            case .message(let viewModel):
                ConsoleMessageDetailsView(viewModel: viewModel, onClose: onClose)
            case .request(let viewModel):
                NetworkInspectorView(viewModel: viewModel, onClose: onClose)
            }
        }
    }

    private func onClose() {
        viewModel.select(nil)
    }
}

final class ConsoleDetailsRouterViewModel: ObservableObject {
    @Published private(set) var viewModel: DetailsViewModel?

    func select(_ entity: NSManagedObject?) {
        if let message = entity as? LoggerMessageEntity {
            if let request = message.request {
                viewModel = .request(.init(request: request))
            } else {
                viewModel = .message(.init(message: message))
            }
        } else if let request = entity as? LoggerNetworkRequestEntity {
            viewModel = .request(.init(request: request))
        } else {
            viewModel = nil
        }
    }

    enum DetailsViewModel {
        case message(ConsoleMessageDetailsViewModel)
        case request(NetworkInspectorViewModel)
    }
}
