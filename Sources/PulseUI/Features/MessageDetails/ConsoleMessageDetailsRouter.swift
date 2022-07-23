// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore

#if os(macOS)

struct ConsoleMessageDetailsRouter: View {
    @ObservedObject var viewModel: ConsoleDetailsPanelViewModel

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

final class ConsoleDetailsPanelViewModel: ObservableObject {
    @Published private(set) var viewModel: DetailsViewModel?
    private let store: LoggerStore

    init(store: LoggerStore) {
        self.store = store
    }

    func select(_ entity: NSManagedObject?) {
        if let message = entity as? LoggerMessageEntity {
            if let request = message.request {
                viewModel = .request(.init(request: request, store: store))
            } else {
                viewModel = .message(.init(store: store, message: message))
            }
        } else if let request = entity as? LoggerNetworkRequestEntity {
            viewModel = .request(.init(request: request, store: store))
        } else {
            viewModel = nil
        }
    }

    enum DetailsViewModel {
        case message(ConsoleMessageDetailsViewModel)
        case request(NetworkInspectorViewModel)
    }
}

#else

struct ConsoleMessageDetailsRouter: View {
    let store: LoggerStore
    @Binding var entity: NSManagedObject?

    var body: some View {
        if let message = entity as? LoggerMessageEntity {
            if let request = message.request {
                NetworkInspectorView(viewModel: .init(request: request, store: store))
            } else {
                ConsoleMessageDetailsView(viewModel: .init(store: store, message: message))
            }
        } else if let request = entity as? LoggerNetworkRequestEntity {
            NetworkInspectorView(viewModel: .init(request: request, store: store))
        }
    }
}

#endif
