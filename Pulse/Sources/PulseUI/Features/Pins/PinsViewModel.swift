// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(macOS)

@available(iOS 13.0, *)
final class PinsViewModel: ObservableObject {
    let store: LoggerStore
    let pins: PinService

    #if os(macOS)
    let list: NotListViewModel<LoggerMessageEntity>
    let details: ConsoleDetailsRouterViewModel
    #endif

    @Published var messages: [LoggerMessageEntity] = []

    private var bag = [AnyCancellable]()

    var showInConsole: ((_ message: LoggerMessageEntity) -> Void)?
    var onDismiss: (() -> Void)?

    init(store: LoggerStore) {
        self.store = store
        self.pins = PinService.service(forStore: store)

        #if os(macOS)
        self.list = NotListViewModel<LoggerMessageEntity>()
        self.details = ConsoleDetailsRouterViewModel(context: AppContext(store: store, pins: pins))
        #endif

        self.refresh(pins.pins)
        pins.$pins.sink { [weak self] pins in
            self?.refresh(pins)
        }.store(in: &bag)
    }

    private func refresh(_ pins: Set<NSManagedObjectID>) {
        messages = pins.compactMap {
            store.container.viewContext.object(with: $0) as? LoggerMessageEntity
        }

        #if os(macOS)
        list.elements = messages
        #endif
    }

    func prepareForSharing() -> ShareItems {
        ConsoleShareService(store: store).share(messages)
    }

    #if os(macOS)
    func selectEntityAt(_ index: Int) {
        details.selectedEntity = messages[index]
    }
    #endif

    func removeAll() {
        pins.removeAll()
    }

    func showInConsole(message: LoggerMessageEntity) {
        showInConsole?(message)
    }

    // MARK: - Temporary

    var shareService: ConsoleShareService {
        ConsoleShareService(store: store)
    }
}

#endif
