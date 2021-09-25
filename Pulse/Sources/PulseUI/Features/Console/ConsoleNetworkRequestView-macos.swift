// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import AppKit
import PulseCore
import Combine

final class ConsoleNetworkRequestView: NSView {
    private let title = NSTextField.label()
    private let badge = CircleView()
    private let details = NSTextField.label()
    private let pin = NSImageView(image: pinImage)
    private let contextMenu = ConsoleNetworkRequestContextMenuView()
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
    }

    override func layout() {
        super.layout()

        badge.frame = CGRect(x: 0, y: 32, width: 8, height: 8)

        title.sizeToFit()
        title.frame = CGRect(x: badge.frame.maxX + 3, y: 29, width: title.bounds.size.width, height: title.bounds.size.height)

        pin.frame = CGRect(x: title.frame.maxX + 3, y: 29, width: 12, height: 14)

        details.frame = CGRect(x: 0, y: 5, width: bounds.width, height: 20)
        contextMenu.frame = bounds
    }

    func display(_ model: ConsoleNetworkRequestViewModel) {
        title.stringValue = model.title
        details.stringValue = model.text
        badge.fillColor = NSColor(model.badgeColor)
        contextMenu.model = model

        cancellable = model.isPinnedPublisher.sink(receiveValue: { [weak self] in
            self?.pin.isHidden = !$0
        })
    }
}

private final class CircleView: NSView {
    var fillColor: NSColor = .red

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(ovalIn: dirtyRect)
        fillColor.setFill()
        path.fill()
    }
}

private let pinImage: NSImage = {
    let image = NSImage(systemSymbolName: "pin", accessibilityDescription: nil)
    let config = NSImage.SymbolConfiguration(textStyle: .caption1)
    return image?.withSymbolConfiguration(config) ?? NSImage()
}()

final class ConsoleNetworkRequestContextMenuView: NSView {
    var model: ConsoleNetworkRequestViewModel?

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let model = model else {
            return nil
        }

        let menu = NSMenu()

        let copyURL = NSMenuItem(title: "Copy URL", action: #selector(buttonCopyURLTapped), keyEquivalent: "")
        copyURL.target = self
        copyURL.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        menu.addItem(copyURL)

        let copyHost = NSMenuItem(title: "Copy Host", action: #selector(buttonCopyHostTapped), keyEquivalent: "")
        copyHost.target = self
        copyHost.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        menu.addItem(copyHost)

        if model.containsResponseData {
            let copyResponse = NSMenuItem(title: "Copy Response", action: #selector(buttonCopyResponseBodyTapped), keyEquivalent: "c")
            copyResponse.target = self
            copyResponse.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            menu.addItem(copyResponse)
        }

        let copyCURL = NSMenuItem(title: "Copy cURL", action: #selector(buttonCopycURLDescriptionTapped), keyEquivalent: "")
        copyCURL.target = self
        copyCURL.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        menu.addItem(copyCURL)

        menu.addItem(NSMenuItem.separator())

        let isPinned = model.isPinned
        let pinItem = NSMenuItem(title: isPinned ? "Remove Pin" : "Pin", action: #selector(togglePinTapped), keyEquivalent: "")
        pinItem.target = self
        pinItem.image = NSImage(systemSymbolName: isPinned ? "pin.slash" : "pin", accessibilityDescription: nil)
        menu.addItem(pinItem)

        if model.showInConsole != nil {
            let showInConsoleItem = NSMenuItem(title: "Show in Console", action: #selector(showInConsole), keyEquivalent: "")
            showInConsoleItem.target = self
            showInConsoleItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
            menu.addItem(showInConsoleItem)
        }

        return menu
    }

    @objc private func buttonCopyURLTapped() {
        NSPasteboard.general.string = model?.url
    }

    @objc private func buttonCopyHostTapped() {
        NSPasteboard.general.string = model?.host
    }

    @objc private func buttonCopyResponseBodyTapped() {
        NSPasteboard.general.string = model?.responseString
    }

    @objc private func buttonCopycURLDescriptionTapped() {
        NSPasteboard.general.string = model?.cURLDescription
    }

    @objc private func togglePinTapped() {
        model?.togglePin()
    }

    @objc private func showInConsole() {
        model?.showInConsole?()
    }
}

#endif
