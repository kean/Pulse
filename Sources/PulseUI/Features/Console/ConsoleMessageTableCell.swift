// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import PulseCore
import Combine
import UIKit

@available(iOS 13.0, *)
final class ConsoleMessageTableCell: UITableViewCell, UIContextMenuInteractionDelegate {
    private let title = UILabel()
    private let timeLabel = UILabel()
    private let details = UILabel()
    private let pin = PinIndicatorView()

    private var model: ConsoleMessageViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        createView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        timeLabel.font = .preferredFont(forTextStyle: .caption1)
        timeLabel.textColor = .secondaryLabel

        let chevron = UIImage(systemName: "chevron.right")?.withConfiguration(UIImage.SymbolConfiguration(textStyle: .caption1)) ?? UIImage()

        let disc = UIImageView(image: chevron)
        disc.tintColor = .separator

        let disclosures = UIStackView(arrangedSubviews: [
            timeLabel, disc
        ])
        disclosures.spacing = 6

        let top = UIStackView(arrangedSubviews: [
            title, pin, UIView(), disclosures
        ])
        top.spacing = 8
        top.alignment = .firstBaseline

        let stack = UIStackView(arrangedSubviews: [
            top,
            details
        ])
        stack.axis = .vertical
        stack.spacing = 6

        contentView.addSubview(stack)
        stack.pinToSuperview(insets: .init(top: 12, left: 16, bottom: 12, right: 16))

        title.font = .preferredFont(forTextStyle: .caption1)
        details.font = .systemFont(ofSize: 15)
        details.numberOfLines = 4

        let interaction = UIContextMenuInteraction(delegate: self)
        self.addInteraction(interaction)
    }

    func display(_ model: ConsoleMessageViewModel) {
        self.model = model

        title.attributedText = model.attributedTitle
        details.text = model.text
        details.textColor = model.textColor2
        timeLabel.text = model.time
        pin.bind(viewModel: model.pinViewModel)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let model = model else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in
            return self.makeMenu(for: model)
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

#endif
