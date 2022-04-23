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

@available(iOS 15.0, tvOS 15.0, watchOS 8.0, *)
struct PinButton2: View {
    @ObservedObject var viewModel: PinButtonViewModel

    var body: some View {
        Button(action: viewModel.togglePin) {
            Label(viewModel.isPinned ? "Remove Pin" : "Pin", systemImage: viewModel.isPinned ? "pin.slash" : "pin")
        }
    }
}

#if os(iOS)
@available(iOS 13.0, *)
extension UIAction {
    static func makePinAction(with viewModel: PinButtonViewModel) -> UIAction {
        UIAction(
            title: viewModel.isPinned ? "Remove Pin" : "Pin",
            image: UIImage(systemName: viewModel.isPinned ? "pin.slash" : "pin"),
            handler: { _ in viewModel.togglePin() }
        )
    }
}

@available(iOS 13.0, *)
final class PinIndicatorView: UIImageView {
    private var viewModel: PinButtonViewModel?
    private var cancellables: [AnyCancellable] = []

    init() {
        super.init(image: pinImage)
        self.tintColor = .systemPink
    }

    func bind(viewModel: PinButtonViewModel) {
        self.viewModel = viewModel
        viewModel.$isPinned.sink { [weak self] isPinned in
            guard let self = self else { return }
            self.isHidden = !isPinned
        }.store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 13.0, *)
private let pinImage: UIImage = {
    let image = UIImage(systemName: "pin")
    return image?.withConfiguration(UIImage.SymbolConfiguration(textStyle: .caption1)) ?? UIImage()
}()
#endif

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
