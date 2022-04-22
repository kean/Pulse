// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#warning("TEMP")

#if os(iOS)

import PulseCore
import Combine
import UIKit

@available(iOS 13.0, *)
final class ConsoleMessageTableCell: UITableViewCell {
    private let title = UILabel()
    private let details = UILabel()
    private let pin = UIImageView(image: pinImage)

//    private let contextMenu = ConsoleMessageContextMenuView()
    private var cancellable: AnyCancellable?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        createView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createView() {
        let stack = UIStackView(arrangedSubviews: [
            title,
            details
        ])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        contentView.addSubview(stack)
        stack.pinToSuperview(insets: .init(top: 12, left: 16, bottom: 12, right: 16))

        title.font = .preferredFont(forTextStyle: .caption1)
        details.font = .systemFont(ofSize: 15)
    }

    func display(_ model: ConsoleMessageViewModel) {
        title.attributedText = model.attributedTitle
        details.text = model.text

        cancellable = model.pinViewModel.$isPinned.sink(receiveValue: { [unowned self] in
            self.pin.isHidden = !$0
        })
//        contextMenu.model = model
    }
}

@available(iOS 13.0, *)
private let pinImage: UIImage = {
    let image = UIImage(systemName: "pin")
    return image?.withConfiguration(UIImage.SymbolConfiguration(textStyle: .caption1)) ?? UIImage()
}()

#warning("TEMP")
// MARK: ContextMenus
//final class ConsoleMessageContextMenuView: NSView {
//    var model: ConsoleMessageViewModel?
//
//    override func menu(for event: NSEvent) -> NSMenu? {
//        guard let model = model else { return nil }
//
//        let menu = NSMenu()
//
//        let copyItem = NSMenuItem(title: "Copy Message", action: #selector(buttonCopyTapped), keyEquivalent: "")
//        copyItem.target = self
//        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
//
//        let isPinned = model.isPinned
//        let pinItem = NSMenuItem(title: isPinned ? "Remove Pin" : "Pin", action: #selector(togglePinTapped), keyEquivalent: "")
//        pinItem.target = self
//        pinItem.image = NSImage(systemSymbolName: isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
//
//        let showInConsoleItem = NSMenuItem(title: "Show in Console", action: #selector(showInConsole), keyEquivalent: "")
//        showInConsoleItem.target = self
//        showInConsoleItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
//
//        menu.addItem(copyItem)
//        menu.addItem(NSMenuItem.separator())
//        menu.addItem(pinItem)
//
//        if model.showInConsole != nil {
//            menu.addItem(showInConsoleItem)
//        }
//
//        return menu
//    }
//
//    @objc private func buttonCopyTapped() {
//        UXPasteboard.general.string = model?.text
//        runHapticFeedback()
//    }
//
//    @objc private func togglePinTapped() {
//        model?.togglePin()
//    }
//
//    @objc private func showInConsole() {
//        model?.showInConsole?()
//    }
//}

#endif
