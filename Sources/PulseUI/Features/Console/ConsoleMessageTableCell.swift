// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import Pulse
import Combine
import UIKit

final class ConsoleMessageTableCell: UITableViewCell, UIContextMenuInteractionDelegate {
    private let title = UILabel()
    private let accessory = ConsoleMessageAccessoryView()
    private let details = UILabel()
    private let pin = PinIndicatorView()

    private var viewModel: ConsoleMessageViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        createView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        selectionStyle = .gray

        let topStack = UIView.hStack(alignment: .center, spacing: 8, [
            title, UIView(), pin, accessory
        ])
        topStack.setCustomSpacing(4, after: pin)
        let stack = UIView.vStack(spacing: 4, [topStack, details])

        contentView.addSubview(stack)
        stack.pinToSuperview(insets: .init(top: 10, left: 16, bottom: 10, right: 12))

        title.font = .preferredFont(forTextStyle: .caption1)
        details.font = .systemFont(ofSize: 15)
        details.numberOfLines = 4

        let interaction = UIContextMenuInteraction(delegate: self)
        self.addInteraction(interaction)
    }

    func display(_ viewModel: ConsoleMessageViewModel) {
        self.viewModel = viewModel

        title.attributedText = viewModel.attributedTitle
        details.text = viewModel.text
        details.textColor = viewModel.textColor2
        accessory.textLabel.text = viewModel.time
        pin.bind(viewModel: viewModel.pinViewModel)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let viewModel = viewModel else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in
            return self.makeMenu(for: viewModel)
        })
    }

    private func makeMenu(for viewModel: ConsoleMessageViewModel) -> UIMenu {
        let share = UIAction(title: "Share Message", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            UIActivityViewController.show(with: viewModel.share())
        }

        let copy = UIAction(title: "Copy Message", image: UIImage(systemName: "doc.on.doc")) { _ in
            UXPasteboard.general.string = viewModel.copy()
            runHapticFeedback()
        }

        let focus = UIAction(title: "Focus \'\(viewModel.focusLabel)\'", image: UIImage(systemName: "eye")) { _ in
            viewModel.focus()
        }

        let hide = UIAction(title: "Hide \'\(viewModel.focusLabel)\'", image: UIImage(systemName: "eye.slash")) { _ in
            viewModel.hide()
        }

        let pin = UIAction.makePinAction(with: viewModel.pinViewModel)

        let shareGroup = UIMenu(title: "Share", options: [.displayInline], children: [share, copy])

        let filtersGroup = UIMenu(title: "Filter", options: [.displayInline], children: [focus, hide])

        return UIMenu(title: "", options: [.displayInline], children: [shareGroup, filtersGroup, pin])
    }
}

final class ConsoleMessageAccessoryView: UIView {
    let textLabel = UILabel()

    private static var chevron = UIImage.make(systemName: "chevron.right", textStyle: .caption1)

    override init(frame: CGRect) {
        super.init(frame: frame)

        textLabel.font = .preferredFont(forTextStyle: .caption1)
        textLabel.textColor = .secondaryLabel
        textLabel.setContentCompressionResistancePriority(.init(800), for: .horizontal)

        let disclosureIndicator = UIImageView(image: ConsoleMessageAccessoryView.chevron)
        disclosureIndicator.tintColor = .separator
        disclosureIndicator.setContentCompressionResistancePriority(.init(800), for: .horizontal)

        let stack = UIStackView.hStack(spacing: 4, [textLabel, disclosureIndicator])
        addSubview(stack)
        stack.pinToSuperview()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
