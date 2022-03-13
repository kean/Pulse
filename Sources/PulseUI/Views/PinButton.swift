//
//// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
struct PinButton: View {
    @ObservedObject var model: PinButtonViewModel
    var isTextNeeded: Bool = true

    var body: some View {
        Button(action: model.togglePin) {
            if isTextNeeded {
                Text(model.isPinned ? "Remove Pin" : "Pin")
            }
            Image(systemName: model.isPinned ? "pin.slash" : "pin")
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
final class PinButtonViewModel: ObservableObject {
    @Published private(set) var isPinned = false
    private let message: LoggerMessageEntity
    private let store: LoggerStore
    private var cancellables: [AnyCancellable] = []

    init(store: LoggerStore, message: LoggerMessageEntity) {
        self.store = store
        self.message = message

        message.publisher(for: \.isPinned).sink { [weak self] in
            guard let self = self else { return }
            self.isPinned = $0
        }.store(in: &cancellables)
    }

    func togglePin() {
        store.togglePin(for: message)
    }
}
