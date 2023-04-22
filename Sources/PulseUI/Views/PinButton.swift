//
// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS)

struct PinButton: View {
    @ObservedObject var viewModel: PinButtonViewModel
    var isTextNeeded: Bool = true

    var body: some View {
        Button(action: viewModel.togglePin) {
            if isTextNeeded {
                Label(viewModel.isPinned ? "Unpin" : "Pin", systemImage: viewModel.isPinned ? "pin.fill" : "pin")
            } else {
                Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
            }
        }
    }
}

struct PinView: View {
    private var message: LoggerMessageEntity?
    @State private var isPinned = false

    init(message: LoggerMessageEntity?) {
        self.message = message
    }

    init(task: NetworkTaskEntity) {
        self.init(message: task.message)
    }

    var body: some View {
        if let message = message {
            Image(systemName: "pin")
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.pink)
                .opacity(isPinned ? 1 : 0)
                .frame(width: 8, height: 8)
                .onReceive(message.publisher(for: \.isPinned).removeDuplicates()) {
                    isPinned = $0
                }
        }
    }
}

final class PinButtonViewModel: ObservableObject {
    @Published private(set) var isPinned = false
    private let message: LoggerMessageEntity?
    private let pins: LoggerStore.Pins?
    private var cancellables: [AnyCancellable] = []

    init(_ message: LoggerMessageEntity) {
        self.message = message
        self.pins = message.managedObjectContext?.userInfo[pinServiceKey] as? LoggerStore.Pins
        self.subscribe()
    }

    init(_ task: NetworkTaskEntity) {
        self.message = task.message
        self.pins = task.managedObjectContext?.userInfo[pinServiceKey] as? LoggerStore.Pins
        self.subscribe()
    }

    private func subscribe() {
        guard let message = message else { return } // Should never happen
        message.publisher(for: \.isPinned).sink { [weak self] in
            guard let self = self else { return }
            self.isPinned = $0
        }.store(in: &cancellables)
    }

    func togglePin() {
        guard let message = message else { return } // Should never happen
        pins?.togglePin(for: message)
    }
}
#endif

private let pinServiceKey = "com.github.kean.pulse.pin-service"
