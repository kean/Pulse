//
//// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

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
                Text(viewModel.isPinned ? "Remove Pin" : "Pin")
            }
            Image(systemName: viewModel.isPinned ? "pin.slash" : "pin")
        }
    }
}

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

#if os(iOS)
extension UIAction {
    static func makePinAction(with viewModel: PinButtonViewModel) -> UIAction {
        UIAction(
            title: viewModel.isPinned ? "Remove Pin" : "Pin",
            image: UIImage(systemName: viewModel.isPinned ? "pin.slash" : "pin"),
            handler: { _ in viewModel.togglePin() }
        )
    }
}

extension UIContextualAction {
    static func makePinAction(with viewModel: PinButtonViewModel) -> UIContextualAction {
        let action = UIContextualAction(
            style: .normal,
            title: viewModel.isPinned ? "Remove Pin" : "Pin",
            handler: { _,_,_  in viewModel.togglePin() }
        )
        action.backgroundColor = .systemBlue
        action.image = UIImage(systemName: viewModel.isPinned ? "pin.slash" : "pin")
        return action
    }
}

final class PinIndicatorView: UIImageView {
    private var viewModel: PinButtonViewModel?
    private var cancellables: [AnyCancellable] = []

    init() {
        super.init(image: pinImage)
        self.tintColor = .systemPink
    }

    func bind(viewModel: PinButtonViewModel) {
        self.viewModel = viewModel
        cancellables = []
        viewModel.$isPinned.sink { [weak self] isPinned in
            guard let self = self else { return }
            self.isHidden = !isPinned
        }.store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private let pinImage: UIImage = {
    let image = UIImage(systemName: "pin")
    return image?.withConfiguration(UIImage.SymbolConfiguration(textStyle: .caption1)) ?? UIImage()
}()
#endif

#endif

// MARK: - ViewModel

protocol Pinnable {
    var pinViewModel: PinButtonViewModel { get }
}

#if os(iOS) || os(macOS)
final class PinButtonViewModel: ObservableObject {
    @Published private(set) var isPinned = false
    private let message: LoggerMessageEntity?
    private let pins: LoggerStore.Pins?
    private var cancellables: [AnyCancellable] = []

    init(message: LoggerMessageEntity) {
        self.message = message
        self.pins = message.managedObjectContext?.userInfo[pinServiceKey] as? LoggerStore.Pins
        self.subscribe()
    }

    init(task: NetworkTaskEntity) {
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
#else
struct PinButtonViewModel {
    init(message: LoggerMessageEntity) {}
    init(task: NetworkTaskEntity) {}
}
#endif

private let pinServiceKey = "com.github.kean.pulse.pin-service"
