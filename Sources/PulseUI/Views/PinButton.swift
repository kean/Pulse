//
//// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

@available(iOS 13.0, tvOS 14.0, watchOS 6.0, *)
struct PinButton: View {
    @ObservedObject var viewModel: PinButtonViewModel
    var isTextNeeded: Bool = true

    var body: some View {
        Button(action: viewModel.togglePin) {
            if isTextNeeded {
                Text(viewModel.isPinned ? "Remove Pin" : "Pin")
            }
            Image(systemName: viewModel.isPinned ? "pin.slash" : "pin")
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct PinView: View {
    @ObservedObject var viewModel: PinButtonViewModel
    let font: Font

    var body: some View {
        if viewModel.isPinned {
            Image(systemName: "pin")
                .font(font)
                .foregroundColor(.secondary)
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 6.0, *)
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
