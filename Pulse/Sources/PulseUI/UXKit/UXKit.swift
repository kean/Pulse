// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import SwiftUI

// A set of typealias and APIs to make AppKit and UIKit more
// compatible with each other

#if os(macOS)
typealias UXColor = NSColor
typealias UXFont = NSFont
typealias UXTextView = NSTextView
typealias UXImage = NSImage
typealias UXPasteboard = NSPasteboard

extension NSColor {
    static var separator: NSColor { separatorColor }
    static var label: NSColor { labelColor }
    static var systemBackground: NSColor { windowBackgroundColor }
    static var secondaryLabel: NSColor { secondaryLabelColor }
    static var secondarySystemFill: NSColor { controlBackgroundColor }
    static var systemGray4: NSColor { systemGray.withAlphaComponent(0.7) }
    static var systemGray3: NSColor { systemGray.withAlphaComponent(0.8) }
    static var systemGray2: NSColor { systemGray.withAlphaComponent(0.9) }
}
#else
typealias UXColor = UIColor
typealias UXFont = UIFont
typealias UXImage = UIImage
#endif

#if os(tvOS)
typealias UXTextView = UITextView
#elseif os(iOS)
typealias UXTextView = UITextView
typealias UXPasteboard = UIPasteboard
#endif

#if os(tvOS)
extension UIColor {
    static var systemBackground: UIColor { .white }
    static var systemGray4: UIColor { systemGray.withAlphaComponent(0.7) }
    static var systemGray3: UIColor { systemGray.withAlphaComponent(0.8) }
    static var systemGray2: UIColor { systemGray.withAlphaComponent(0.9) }
    static var controlBackgroundColor: UIColor { .clear }
}
#endif

// MARK: - FontSize

enum FontSize {
    static var body: CGFloat {
        #if os(macOS)
            return 11
        #elseif os(tvOS)
            return 24
        #else
            return 12
        #endif
    }
}

// MARK: - NSTextView

#if os(iOS)
extension UITextView {
    var isAutomaticLinkDetectionEnabled: Bool {
        get { dataDetectorTypes.contains(.link) }
        set {
            if newValue {
                dataDetectorTypes.insert(.link)
            } else {
                dataDetectorTypes.remove(.link)
            }
        }
    }
}

func runHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
}
#endif

func hideKeyboard() {
    #if os(iOS)
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
}

#if os(macOS)
extension NSTextView {
    var attributedText: NSAttributedString? {
        get { nil }
        set { textStorage?.setAttributedString(newValue ?? NSAttributedString()) }
    }

    var text: String {
        get { string }
        set { string = newValue }
    }
}

enum NSHapticFeedabackTypePlaceholder {
    case success, warning, error
}

func runHapticFeedback(_ type: NSHapticFeedabackTypePlaceholder = .success) {
    // Do nothing, not
}
#endif

// MARK: - UIImageView

#if os(iOS) || os(watchOS) || os(tvOS)
@available(iOS 13.0, tvOS 14.0, watchOS 6, *)
extension Image {
    init(uxImage: UXImage) {
        self.init(uiImage: uxImage)
    }
}
#endif

#if os(macOS)
@available(iOS 13.0, *)
extension Image {
    init(uxImage: UXImage) {
        self.init(nsImage: uxImage)
    }
}
#endif

// MARK: - NSPasteboard

#if os(macOS)
extension NSPasteboard {
    var string: String? {
        get { string(forType: .string) ?? "" }
        set {
            guard let newValue = newValue else { return }
            declareTypes([.string], owner: nil)
            setString(newValue, forType: .string)
        }
    }
}

extension NSImage {
    var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

extension NSTextField {
    static func label() -> NSTextField {
        let label = NSTextField()
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}
#endif

// MARK: - UIViewController (Extensions)

#if os(iOS)
@available(iOS 13.0, *)
extension UIViewController {
    @discardableResult
    static func present<ContentView: View>(_ closure: (_ dismiss: @escaping () -> Void) -> ContentView) -> UIViewController? {
        present { UIHostingController(rootView: closure($0)) }
    }

    @discardableResult
    static func present(_ closure: (_ dismiss: @escaping () -> Void) -> UIViewController) -> UIViewController? {
        guard let window = UIApplication.shared.windows.filter({ $0.isKeyWindow }).first,
              let rootVC = window.rootViewController else {
            return nil
        }
        let vc = closure({ [weak rootVC] in
            rootVC?.dismiss(animated: true, completion: nil)
        })
        rootVC.present(vc, animated: true, completion: nil)
        return vc
    }
}
#endif
