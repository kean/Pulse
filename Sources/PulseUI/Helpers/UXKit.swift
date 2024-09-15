// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(macOS)
import AppKit
#else
import UIKit
#endif

import SwiftUI

// A set of typealias and APIs to make AppKit and UIKit more
// compatible with each other

package struct Palette {
#if os(watchOS)
    package static var red: UXColor { Palette.darkRed }
    package static var pink: UXColor { Palette.darkPink }
#else
    package static var red: UXColor {
        UXColor.dynamic(light: Palette.lightRed, dark: Palette.darkRed)
    }

    package static var pink: UXColor {
        UXColor.dynamic(light: Palette.lightPink, dark: Palette.darkPink)
    }
#endif

    private static let lightRed = UXColor(red: 196.0/255.0, green: 26.0/255.0, blue: 22.0/255.0, alpha: 1.0)
    private static let darkRed = UXColor(red: 254.0/255.0, green: 129.0/255.0, blue: 112.0/255.0, alpha: 1.0)

    private static let lightPink = UXColor(red: 155.0/255.0, green: 35.0/255.0, blue: 147.00/255.0, alpha: 1.0)
    private static let darkPink = UXColor(red: 252.0/255.0, green: 95.0/255.0, blue: 163.0/255.0, alpha: 1.0)
}

#if os(macOS)
package typealias UXColor = NSColor
package typealias UXFont = NSFont
package typealias UXTextView = NSTextView
package typealias UXImage = NSImage
package typealias UXPasteboard = NSPasteboard

extension NSColor {
    package static var separator: NSColor { separatorColor }
    package static var label: NSColor { labelColor }
    package static var systemBackground: NSColor { windowBackgroundColor }
    package static var secondaryLabel: NSColor { secondaryLabelColor }
    package static var secondarySystemFill: NSColor { controlBackgroundColor }
    static var systemGray4: NSColor { systemGray.withAlphaComponent(0.7) }
    static var systemGray3: NSColor { systemGray.withAlphaComponent(0.8) }
    static var systemGray2: NSColor { systemGray.withAlphaComponent(0.9) }
}

extension NSColor {
    package static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
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
package typealias UXColor = UIColor
package typealias UXFont = UIFont
package typealias UXImage = UIImage

extension UIColor {
    package static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
#if !os(watchOS)
        UIColor {
            switch $0.userInterfaceStyle {
            case .dark:
                return dark
            default:
                return light
            }
        }
#else
        dark
#endif
    }
}

#endif

#if os(tvOS)
package typealias UXTextView = UITextView
#elseif os(iOS) || os(visionOS)
package typealias UXTextView = UITextView
package typealias UXPasteboard = UIPasteboard
#endif

#if os(tvOS)
extension UIColor {
    static var systemBackground: UIColor { .white }
    static var systemGray2: UIColor { systemGray.withAlphaComponent(0.9) }
    static var systemGray3: UIColor { systemGray.withAlphaComponent(0.8) }
    static var systemGray4: UIColor { systemGray.withAlphaComponent(0.7) }
}
#endif

#if os(watchOS)
extension UXColor {
    static let label = UIColor(Color.primary)
    static let secondaryLabel = UIColor(Color.secondary)
    static let systemOrange = UIColor(Color.orange)
    static let systemRed = UIColor(Color.red)
}
#endif

// MARK: - NSTextView

#if os(iOS) || os(visionOS)
extension UITextView {
    package var isAutomaticLinkDetectionEnabled: Bool {
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
#endif

#if os(iOS)
func runHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType = .success) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
}
#endif

#if os(visionOS)
enum VisionHapticFeedabackTypePlaceholder {
    case success, warning, error
}
func runHapticFeedback(_ type: VisionHapticFeedabackTypePlaceholder = .success) {
    // Do nothing
}
#endif

#if os(macOS)
extension NSTextView {
    package var attributedText: NSAttributedString? {
        get { nil }
        set { textStorage?.setAttributedString(newValue ?? NSAttributedString()) }
    }

    package var text: String {
        get { string }
        set { string = newValue }
    }
}

enum NSHapticFeedabackTypePlaceholder {
    case success, warning, error
}

func runHapticFeedback(_ type: NSHapticFeedabackTypePlaceholder = .success) {
    // Do nothing
}
#endif

extension Image {
#if os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
    package init(uxImage: UXImage) {
        self.init(uiImage: uxImage)
    }
#elseif os(macOS)
    package init(uxImage: UXImage) {
        self.init(nsImage: uxImage)
    }
#endif
}

#if os(macOS)
extension NSPasteboard {
    package var string: String? {
        get { string(forType: .string) ?? "" }
        set {
            guard let newValue = newValue else { return }
            declareTypes([.string], owner: nil)
            setString(newValue, forType: .string)
        }
    }
}

extension NSImage {
    package var cgImage: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

#endif
