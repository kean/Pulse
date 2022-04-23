// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import PulseCore
import Combine
import UIKit

@available(iOS 13.0, *)
final class ConsoleNetworkRequestTableCell: UITableViewCell, UIContextMenuInteractionDelegate {
    private let badge = CircleView()
    private let title = UILabel()
    private let accessory = ConsoleMessageAccessoryView()
    private let details = UILabel()
    private let pin = PinIndicatorView()

    private var viewModel: ConsoleNetworkRequestViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        createView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        let stack = UIView.vStack(spacing: 4, [
            .hStack(alignment: .center, spacing: 8, [
                badge, title, UIView(), accessory
            ]),
            details
        ])

        contentView.addSubview(stack)
        stack.pinToSuperview(insets: .init(top: 10, left: 16, bottom: 10, right: 16))

        contentView.addSubview(pin)
        pin.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pin.firstBaselineAnchor.constraint(equalTo: title.firstBaselineAnchor),
            pin.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 6)
        ])

        title.font = .preferredFont(forTextStyle: .caption1)
        title.textColor = .secondaryLabel
        details.font = .systemFont(ofSize: 15)
        details.numberOfLines = 4

        let interaction = UIContextMenuInteraction(delegate: self)
        self.addInteraction(interaction)
    }

    func display(_ viewModel: ConsoleNetworkRequestViewModel) {
        self.viewModel = viewModel

        badge.fillColor = viewModel.badgeColor
        title.text = viewModel.title
        details.text = viewModel.text
        accessory.textLabel.text = viewModel.time
        pin.bind(viewModel: viewModel.pinViewModel)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let viewModel = viewModel else {
            return nil
        }
        return nil
//        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in
//            return self.makeMenu(for: viewModel)
//        })
    }
//
//    private func makeMenu(for viewModel: ConsoleMessageViewModel) -> UIMenu {
//        let share = UIAction(title: "Share Message", image: UIImage(systemName: "square.and.arrow.up")) { _ in
//            UIActivityViewController.show(with: viewModel.share())
//        }
//
//        let copy = UIAction(title: "Copy Message", image: UIImage(systemName: "doc.on.doc")) { _ in
//            UXPasteboard.general.string = viewModel.copy()
//            runHapticFeedback()
//        }
//
//        let focus = UIAction(title: "Focus \'\(viewModel.focusLabel)\'", image: UIImage(systemName: "eye")) { _ in
//            viewModel.focus()
//        }
//
//        let hide = UIAction(title: "Hide \'\(viewModel.focusLabel)\'", image: UIImage(systemName: "eye.slash")) { _ in
//            viewModel.hide()
//        }
//
//        let pin = UIAction.makePinAction(with: viewModel.pinViewModel)
//
//        let shareGroup = UIMenu(title: "Share", options: [.displayInline], children: [share, copy])
//
//        let filtersGroup = UIMenu(title: "Filter", options: [.displayInline], children: [focus, hide])
//
//        return UIMenu(title: "", options: [.displayInline], children: [shareGroup, filtersGroup, pin])
//    }
}

//final class ConsoleNetworkRequestView: NSView {
//    private let title = NSTextField.label()
//    private let badge = CircleView()
//    private let details = NSTextField.label()
//    private let pin = NSImageView(image: pinImage)
//    private let contextMenu = ConsoleNetworkRequestContextMenuView()
//    private var cancellable: AnyCancellable?
//
//    override init(frame frameRect: NSRect) {
//        super.init(frame: frameRect)
//        createView()
//    }
//
//    required init?(coder: NSCoder) {
//        super.init(coder: coder)
//        createView()
//    }
//
//    private func createView() {
//        addSubview(title)
//        addSubview(details)
//        addSubview(badge)
//        addSubview(pin)
//        addSubview(contextMenu)
//
//        title.font = .preferredFont(forTextStyle: .caption1, options: [:])
//        title.textColor = NSColor.secondaryLabel
//    }
//
//    override func layout() {
//        super.layout()
//
//        badge.frame = CGRect(x: 0, y: 32, width: 8, height: 8)
//
//        title.sizeToFit()
//        title.frame = CGRect(x: badge.frame.maxX + 3, y: 29, width: title.bounds.size.width, height: title.bounds.size.height)
//
//        pin.frame = CGRect(x: title.frame.maxX + 3, y: 29, width: 12, height: 14)
//
//        details.frame = CGRect(x: 0, y: 5, width: bounds.width, height: 20)
//        contextMenu.frame = bounds
//    }
//
//    func display(_ model: ConsoleNetworkRequestViewModel) {
//        title.stringValue = model.title
//        details.stringValue = model.text
//        badge.fillColor = NSColor(model.badgeColor)
//        contextMenu.model = model
//
//        cancellable = model.isPinnedPublisher.sink(receiveValue: { [weak self] in
//            self?.pin.isHidden = !$0
//        })
//    }
//}
//

@available(iOS 13.0, *)
private final class CircleView: UIView {
    var fillColor: UIColor = .red

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 10),
            heightAnchor.constraint(equalToConstant: 10),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)

        let path = UIBezierPath(ovalIn: rect)
        fillColor.setFill()
        path.fill()
    }
}

#endif
