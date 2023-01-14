// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import Pulse
import Combine
import UIKit

final class ConsoleNetworkRequestTableCell: UITableViewCell, UIContextMenuInteractionDelegate {
    private let badge = CircleView()
    private let title = UILabel()
    private let typeIcon = UIImageView()
    private let accessory = ConsoleMessageAccessoryView()
    private let details = UILabel()
    private let pin = PinIndicatorView()
    private var state: NetworkTaskEntity.State?

    private var viewModel: ConsoleNetworkRequestViewModel?
    private var cancellable1: AnyCancellable?
    private var cancellable2: AnyCancellable?

    private var titleAttributes: [NSAttributedString.Key: Any] = [:]

    private var isAnimating = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        titleAttributes = TextHelper().attributes(role: .subheadline, style: .monospacedDigital, width: .condensed, color: .secondaryLabel)
        titleAttributes[.paragraphStyle] = {
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            return style
        }()

        super.init(style: style, reuseIdentifier: reuseIdentifier)
        createView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        selectionStyle = .gray

        let topStack = UIView.hStack(alignment: .center, spacing: 8, [
            badge, title, UIView(), pin, accessory
        ])
        topStack.setCustomSpacing(4, after: pin)
        let stack = UIView.vStack(spacing: 4, [topStack, details])

        contentView.addSubview(stack)
        stack.pinToSuperview(insets: .init(top: 10, left: 16, bottom: 10, right: 12))

        details.font = .systemFont(ofSize: 15)

        let interaction = UIContextMenuInteraction(delegate: self)
        self.addInteraction(interaction)
    }

    func display(_ viewModel: ConsoleNetworkRequestViewModel) {
        self.viewModel = viewModel
        self.state = nil
        self.refresh()

        self.cancellable1 = viewModel.objectWillChange.sink { [weak self] in
            self?.refresh()
        }
        self.cancellable2 = viewModel.progress.objectWillChange.sink { [weak self] in
            self?.refresh(onlyTitle: true)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        if isAnimating {
            isAnimating = false
            contentView.backgroundColor = .clear
            layer.removeAllAnimations()
        }
    }

    private func refresh(onlyTitle: Bool = false) {
        guard let viewModel = viewModel else { return }

        if let state = self.state, state != viewModel.state {
            self.isAnimating = true
            UIView.animate(withDuration: 0.33, delay: 0, options: [.allowUserInteraction]) {
                self.contentView.backgroundColor = viewModel.badgeColor.withAlphaComponent(0.15)
            } completion: { _ in
                guard self.isAnimating else { return }
                self.isAnimating = false
                UIView.animate(withDuration: 1.0, delay: 0.5, options: [.allowUserInteraction]) {
                    self.contentView.backgroundColor = .clear
                }
            }
        }
        self.state = viewModel.state

        var headline = ConsoleFormatter.subheadline(for: viewModel.task, hasTime: false)
        if let details = viewModel.progress.details {
            headline.append(ConsoleFormatter.separator + details)
        }
        title.attributedText = NSAttributedString(string: headline, attributes: titleAttributes)

        if !onlyTitle {
            details.numberOfLines = ConsoleSettings.shared.lineLimit
            badge.fillColor = viewModel.badgeColor
            details.text = viewModel.task.url ?? "–"
            accessory.textLabel.attributedText = NSAttributedString(string: viewModel.time, attributes: titleAttributes)
            pin.bind(viewModel: viewModel.pinViewModel)
        }
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
            UIActivityViewController.show(with: viewModel.share(as: .plainText))
        }

        let shareAsHTML = UIAction(title: "Share as HTML", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            UIActivityViewController.show(with: viewModel.share(as: .html))
        }

        let shareAsPDF = UIAction(title: "Share as PDF", image: UIImage(systemName: "square.and.arrow.up")) { _ in
            UIActivityViewController.show(with: viewModel.share(as: .pdf))
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

        let shareGroup = UIMenu(title: "Share...", image: UIImage(systemName: "square.and.arrow.up"), options: [], children: [shareAsText, shareAsHTML, shareAsPDF, shareAsCURL])

        let copyGroup = UIMenu(title: "Copy...", image: UIImage(systemName: "doc.on.doc"), options: [], children: copyItems)

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
