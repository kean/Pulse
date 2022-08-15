// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import SwiftUI

// A set of typealias and APIs to make AppKit and UIKit more
// compatible with each other

struct Palette {
    #if !os(watchOS)
    static var red: UXColor {
        UXColor.dynamic(light: Palette.lightRed, dark: Palette.darkRed)
    }

    private static let lightRed = UXColor(red: 196.0/255.0, green: 26.0/255.0, blue: 22.0/255.0, alpha: 1.0)
    private static let darkRed = UXColor(red: 252.0/255.0, green: 106.0/255.0, blue: 93.0/255.0, alpha: 1.0)

    static var pink: UXColor {
        UXColor.dynamic(light: Palette.lightPink, dark: Palette.darkPink)
    }

    private static let lightPink = UXColor(red: 155.0/255.0, green: 35.0/255.0, blue: 147.00/255.0, alpha: 1.0)
    private static let darkPink = UXColor(red: 252.0/255.0, green: 95.0/255.0, blue: 163.0/255.0, alpha: 1.0)
    #else
    static var red: UXColor { UXColor(Color.red) }
    static var pink: UXColor { UXColor(Color.pink) }
    #endif
}

#if os(macOS)
typealias UXView = NSView
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

extension NSColor {
    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) {
            switch $0.name {
            case .darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua, .accessibilityHighContrastVibrantDark:
                return dark
            default:
                return light
            }
        }
    }
}

#else
#if os(iOS)
typealias UXView = UIView
#endif
typealias UXColor = UIColor
typealias UXFont = UIFont
typealias UXImage = UIImage

#if !os(watchOS)
extension UIColor {
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor {
            switch $0.userInterfaceStyle {
            case .dark:
                return dark
            default:
                return light
            }
        }
    }
}
#endif

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
        #if os(iOS)
            return 12
        #elseif os(macOS)
            return 12
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
extension Image {
    init(uxImage: UXImage) {
        self.init(uiImage: uxImage)
    }
}
#endif

#if os(macOS)
extension Image {
    init(uxImage: UXImage) {
        self.init(nsImage: uxImage)
    }
}
#endif

// MARK: - Misc

extension NSParagraphStyle {
    static func make(lineHeight: CGFloat) -> NSParagraphStyle {
        let ps = NSMutableParagraphStyle()
        ps.maximumLineHeight = lineHeight
        ps.minimumLineHeight = lineHeight
        return ps
    }
}

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

extension NSAttributedString {
    static func makeAttachment(with image: NSImage?, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = image
        let string = NSMutableAttributedString(attachment: attachment)
        string.addAttributes(attributes)
        return NSAttributedString(attributedString: string)
    }
}
#endif
