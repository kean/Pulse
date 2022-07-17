// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import PulseCore
import Combine
import UIKit

final class ConsoleNetworkRequestTableCell: UITableViewCell, UIContextMenuInteractionDelegate {
    private let badge = CircleView()
    private let title = UILabel()
    private let accessory = ConsoleMessageAccessoryView()
    private let details = UILabel()
    private let pin = PinIndicatorView()
    private var state: LoggerNetworkRequestEntity.State?

    private var viewModel: ConsoleNetworkRequestViewModel?
    private var cancellable: AnyCancellable?

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
        stack.pinToSuperview(insets: .init(top: 10, left: 16, bottom: 10, right: 12))

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
        self.state = nil
        self.refresh()

        self.cancellable?.cancel()
        self.cancellable = viewModel.objectWillChange.sink { [weak self] in
            self?.refresh()
        }
    }

    private func refresh() {
        guard let viewModel = viewModel else { return }

        if let state = self.state, state != viewModel.state {
            UIView.animate(withDuration: 0.33, delay: 0, options: [.allowUserInteraction]) {
                self.backgroundColor = viewModel.badgeColor.withAlphaComponent(0.15)
            } completion: { _ in
                UIView.animate(withDuration: 1.0, delay: 0.5, options: [.allowUserInteraction]) {
                    self.backgroundColor = .clear
                }
            }
        }

        badge.fillColor = viewModel.badgeColor
        title.text = viewModel.title
        details.text = viewModel.text
        accessory.textLabel.text = viewModel.time
        pin.bind(viewModel: viewModel.pinViewModel)
        state = viewModel.state
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let viewModel = viewModel else {
            return nil
        }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: { _ in
            return self.makeMenu(for: viewModel)
        })
    }

    private func makeMenu(for viewModel: ConsoleNetworkRequestViewModel) -> UIMenu {
        let shareAsText = UIAction(title: "Share as Plain Text", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            UIActivityViewController.show(with: viewModel.shareAsPlainText())
        }

        let shareAsMarkdown = UIAction(title: "Share as Markdown", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            UIActivityViewController.show(with: viewModel.shareAsMarkdown())
        }

        let shareAsHTML = UIAction(title: "Share as HTML", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            UIActivityViewController.show(with: viewModel.shareAsHTML())
        }

        let shareAsCURL = UIAction(title: "Share as cURL", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            UIActivityViewController.show(with: viewModel.shareAsCURL())
        }

        var copyItems: [UIAction] = []
        if let url = viewModel.url {
            copyItems.append(UIAction(title: "Copy URL", image: UIImage(systemName: "doc.on.doc")) { _ in
                UXPasteboard.general.string = url
                runHapticFeedback()
            })
        }
        if let host = viewModel.host {
            copyItems.append(UIAction(title: "Copy Host", image: UIImage(systemName: "doc.on.doc")) { _ in
                UXPasteboard.general.string = host
                runHapticFeedback()
            })
        }
        if viewModel.containsResponseData {
            copyItems.append(UIAction(title: "Copy Response", image: UIImage(systemName: "doc.on.doc")) { _ in
                UXPasteboard.general.string = viewModel.responseString
                runHapticFeedback()
            })
        }

        let pin = UIAction.makePinAction(with: viewModel.pinViewModel)

        let shareGroup = UIMenu(title: "Share", options: [.displayInline], children: [shareAsText, shareAsMarkdown, shareAsHTML, shareAsCURL])

        let copyGroup = UIMenu(title: "Copy", options: [.displayInline], children: copyItems)

        return UIMenu(title: "", options: [.displayInline], children: [shareGroup, copyGroup, pin])
    }
}

private final class CircleView: UIView {
    var fillColor: UIColor = .red {
        didSet {
            setNeedsDisplay()
        }
    }

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
