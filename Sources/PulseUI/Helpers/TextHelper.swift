// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI

/// Manages text attributes.
final class TextHelper {
    private var cachedAttributes: [AttributesKey: [NSAttributedString.Key: Any]] = [:]
    private var cachedFonts: [TextStyle: UXFont] = [:]

    init() {}

    func attributes(
        role: TextRole,
        style: TextFontStyle = .proportional,
        weight: UXFont.Weight = .regular,
        width: TextWidth = .standard,
        color: UXColor? = .label
    ) -> [NSAttributedString.Key: Any] {
        attributes(style: .init(role: role, style: style, weight: weight, width: width), color: color)
    }

    private(set) lazy var spacerAttributes: [NSAttributedString.Key: Any] = [
        .font: scaled(font: UXFont.systemFont(ofSize: 10))
    ]

    func attributes(style: TextStyle, color: UXColor?) -> [NSAttributedString.Key: Any] {
        let key = AttributesKey(textStyle: style, color: color)
        if let attributes = cachedAttributes[key] {
            return attributes
        }
        let attributes = makeAttributes(style: style, color: color)
        cachedAttributes[key] = attributes
        return attributes
    }

    func font(style: TextStyle) -> UXFont {
        if let font = cachedFonts[style] {
            return font
        }
        let font = makeFont(style: style)
        cachedFonts[style] = font
        return font
    }

    private let titleParagraphStyle: NSParagraphStyle = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = -6
        return paragraphStyle
    }()

    private let bodyParagraphStyle: NSParagraphStyle = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 3
        return paragraphStyle
    }()

    private func makeAttributes(style: TextStyle, color: UXColor?) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [:]
        let font = self.font(style: style)
        attributes[.font] = font
        attributes[.paragraphStyle] = style.role == .title ? titleParagraphStyle : bodyParagraphStyle
        if style.width == .condensed {
            attributes[.kern] = -0.4
        } else if style.style == .monospaced {
            attributes[.kern] = -0.3
        }
        attributes[.foregroundColor] = color
        if style.role == .subheadline {
            attributes[.subheadline] = true
        }
        return attributes
    }

    private func makeFont(style: TextStyle) -> UXFont {
        var size: CGFloat
        let body2Size = (0.9 * getPreferredFontSize(for: .body)).rounded()
        switch style.role {
#if os(watchOS)
        case .title: size = getPreferredFontSize(for: .title2)
#else
        case .title: size = getPreferredFontSize(for: .title1)
#endif
        case .subheadline:
#if os(macOS)
            size = (0.9 * body2Size).rounded()
#else
            size = (0.84 * body2Size).rounded()
#endif
        case .body: size = getPreferredFontSize(for: .body)
        case .body2: size = body2Size
        }
#if !os(macOS)
        if style.style == .monospaced { size -= 2 } // Appears larger than regular
#endif
        return scaled(font: {
            switch style.style {
            case .proportional: return .systemFont(ofSize: size, weight: style.weight)
            case .monospaced: return .monospacedSystemFont(ofSize: size, weight: style.weight)
            case .monospacedDigital: return .monospacedDigitSystemFont(ofSize: size, weight: style.weight)
            }
        }())
    }

    private func scaled(font: UXFont) -> UXFont {
#if os(iOS) || os(tvOS) || os(watchOS)
        return UIFontMetrics.default.scaledFont(for: font)
#else
        return font
#endif
    }

    private struct AttributesKey: Hashable {
        let textStyle: TextStyle
        let color: UXColor?
    }
}

struct TextStyle: Hashable {
    var role: TextRole
    var style: TextFontStyle = .proportional
    var weight: UXFont.Weight = .regular
    var width: TextWidth = .standard
}

enum TextRole {
    /// Large title.
    case title
    /// Section headline (small).
    ///
    /// Font size: iOS 12, macOS 10, tvOS 21, watchOS 11
    case subheadline
    /// Regular-sized body.
    ///
    /// Font size: iOS 17, macOS 13, tvOS 29, watchOS 16.
    case body
    /// Smaller body for console and other views where information has to be
    /// condensed.
    ///
    /// Font size: iOS 15, macOS 12, tvOS 26, watchOS 14.
    case body2
}

enum TextFontStyle {
    case proportional
    case monospaced
    case monospacedDigital
}

enum TextWidth {
    case condensed
    case standard
}

private func getPreferredFontSize(for style: UXFont.TextStyle) -> CGFloat {
    UXFont.preferredFont(forTextStyle: style).fontDescriptor.pointSize
}
