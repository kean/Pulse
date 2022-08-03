// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import CoreData
import PulseCore
import Combine
import SwiftUI

#if os(iOS)

final class PinsViewModel: ObservableObject {
    let table: ConsoleTableViewModel

    @Published private(set) var messages: [LoggerMessageEntity] = [] {
        didSet { table.entities = messages }
    }

    let details: ConsoleDetailsRouterViewModel

    var onDismiss: (() -> Void)?

    private let service: PinsService
    private let store: LoggerStore
    private var cancellables = [AnyCancellable]()

    init(store: LoggerStore) {
        self.store = store
        self.service = PinsService.service(for: store)
        self.details = ConsoleDetailsRouterViewModel(store: store)
        self.table = ConsoleTableViewModel(store: store, searchCriteriaViewModel: nil)

        service.$pinnedMessageIds.sink { [weak self] in
            self?.refresh(with: $0)
        }.store(in: &cancellables)
    }

    private func refresh(with pinnedMessageIds: Set<NSManagedObjectID>) {
        guard isActive else { return }
        messages = pinnedMessageIds.compactMap {
            store.viewContext.object(with: $0) as? LoggerMessageEntity
        }
    }

    var isActive = false {
        didSet {
            if isActive {
                refresh(with: service.pinnedMessageIds)
            }
        }
    }

    func removeAllPins() {
        service.removeAllPins()
    }
}

#endif
