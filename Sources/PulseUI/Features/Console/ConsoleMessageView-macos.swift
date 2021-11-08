// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import AppKit
import PulseCore
import Combine

final class ConsoleMessageView: NSView {
    private let title = NSTextField.label()
    private let badge = NSTextField.label()
    private let details = NSTextField.label()
    private let pin = NSImageView(image: pinImage)
    private let contextMenu = ConsoleMessageContextMenuView()
    private var cancellable: AnyCancellable?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        createView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        createView()
    }

    private func createView() {
        addSubview(title)
        addSubview(details)
        addSubview(badge)
        addSubview(pin)
        addSubview(contextMenu)

        title.font = .preferredFont(forTextStyle: .caption1, options: [:])
        title.textColor = NSColor.secondaryLabel
        badge.font = .preferredFont(forTextStyle: .caption1, options: [:])
    }

    override func layout() {
        super.layout()

        if !badge.isHidden {
            badge.sizeToFit()
            badge.frame = CGRect(x: 0, y: 29, width: badge.bounds.size.width, height: badge.bounds.size.height)
        }

        title.sizeToFit()
        let titleX = badge.isHidden ? 0 : badge.frame.maxX
        title.frame = CGRect(x: titleX, y: 29, width: title.bounds.size.width, height: title.bounds.size.height)

        pin.frame = CGRect(x: title.frame.maxX + 3, y: 29, width: 12, height: 14)

        details.frame = CGRect(x: 0, y: 5, width: bounds.width, height: 20)
        contextMenu.frame = bounds
    }

    func display(_ model: ConsoleMessageViewModel) {
        title.stringValue = model.title
        details.stringValue = model.text
        details.textColor = NSColor(model.textColor)

        badge.isHidden = model.badge == nil
        if let model = model.badge {
            badge.stringValue = model.title
            badge.textColor = NSColor(model.color)
            title.stringValue = "· \(title.stringValue)"
        }

        cancellable = model.isPinnedPublisher.sink(receiveValue: { [unowned self] in
            self.pin.isHidden = !$0
        })
        contextMenu.model = model
    }
}

private let pinImage: NSImage = {
    let image = NSImage(systemSymbolName: "pin", accessibilityDescription: nil)
    let config = NSImage.SymbolConfiguration(textStyle: .caption1)
    return image?.withSymbolConfiguration(config) ?? NSImage()
}()

// MARK: ContextMenus

final class ConsoleMessageContextMenuView: NSView {
    var model: ConsoleMessageViewModel?

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let model = model else { return nil }

        let menu = NSMenu()

        let copyItem = NSMenuItem(title: "Copy Message", action: #selector(buttonCopyTapped), keyEquivalent: "")
        copyItem.target = self
        copyItem.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)

        let isPinned = model.isPinned
        let pinItem = NSMenuItem(title: isPinned ? "Remove Pin" : "Pin", action: #selector(togglePinTapped), keyEquivalent: "")
        pinItem.target = self
        pinItem.image = NSImage(systemSymbolName: isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)

        let showInConsoleItem = NSMenuItem(title: "Show in Console", action: #selector(showInConsole), keyEquivalent: "")
        showInConsoleItem.target = self
        showInConsoleItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)

        menu.addItem(copyItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(pinItem)

        if model.showInConsole != nil {
            menu.addItem(showInConsoleItem)
        }

        return menu
    }

    @objc private func buttonCopyTapped() {
        UXPasteboard.general.string = model?.text
        runHapticFeedback()
    }

    @objc private func togglePinTapped() {
        model?.togglePin()
    }

    @objc private func showInConsole() {
        model?.showInConsole?()
    }
}

#endif
