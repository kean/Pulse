// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import AppKit
import Pulse

// TODO: refactor
final class RichTextViewLayoutManager: NSLayoutManager {
    override func drawUnderline(forGlyphRange glyphRange: NSRange,
        underlineType underlineVal: NSUnderlineStyle,
        baselineOffset: CGFloat,
        lineFragmentRect lineRect: CGRect,
        lineFragmentGlyphRange lineGlyphRange: NSRange,
        containerOrigin: CGPoint
    ) {
        guard let style = RichTextViewUnderlyingStyle(rawValue: underlineVal.rawValue) else {
            super.drawUnderline(forGlyphRange: glyphRange, underlineType: underlineVal, baselineOffset: baselineOffset, lineFragmentRect: lineRect, lineFragmentGlyphRange: lineGlyphRange, containerOrigin: containerOrigin)
            return
        }

        let firstPosition  = location(forGlyphAt: glyphRange.location).x

        var lastPosition: CGFloat

        if NSMaxRange(glyphRange) < NSMaxRange(lineGlyphRange) {
            lastPosition = location(forGlyphAt: NSMaxRange(glyphRange)).x
        } else {
            lastPosition = lineFragmentUsedRect(
                forGlyphAt: NSMaxRange(glyphRange) - 1,
                effectiveRange: nil).size.width - 5
        }

        switch style {
        case .searchResult, .searchResultHighlighted, .more:
            var bubbleRect = lineRect
            let height = max(15, bubbleRect.size.height * 3.5 / 4.0) // replace your under line height
            bubbleRect.origin.x = firstPosition
            bubbleRect.size.width = lastPosition - firstPosition
            bubbleRect.size.height = height

            bubbleRect.origin.x += containerOrigin.x
            bubbleRect.origin.y += containerOrigin.y

            bubbleRect = bubbleRect.integral.insetBy(dx: -0.5, dy: -0.5)

            if style == .more {
                bubbleRect = bubbleRect.insetBy(dx: -0.5, dy: 2)
            }
            if style == .error {
                bubbleRect = bubbleRect.insetBy(dx: -1, dy: 0)
            }

            let path = NSBezierPath(roundedRect: bubbleRect, xRadius: 4, yRadius: 4)
            let color: NSColor
            switch style {
            case .searchResult: color = Palette.searchBackground
            case .searchResultHighlighted: color = Palette.yellow
            case .more: color = Palette.searchBackground
            case .error: fatalError()
            }
            color.setFill()
            path.fill()
        case .error:
            super.drawUnderline(forGlyphRange: glyphRange, underlineType: NSUnderlineStyle.thick, baselineOffset: baselineOffset, lineFragmentRect: lineRect, lineFragmentGlyphRange: lineGlyphRange, containerOrigin: containerOrigin)

            guard let error = textStorage?.attribute(.decodingError, at: glyphRange.location, effectiveRange: nil) as? NetworkLogger.DecodingError else {
                return assertionFailure("Decoding error missing")
            }

            NSColor.red.withAlphaComponent(0.1).setFill()
            lineRect.offsetBy(dx: 0, dy: containerOrigin.y).fill()

            lastPosition = location(forGlyphAt: NSMaxRange(lineGlyphRange)-1).x

            let attributes = TextHelper().attributes(role: .subheadline, weight: .medium)
            let string = NSAttributedString(string: error.shortDescription, attributes: attributes)
            let options: NSString.DrawingOptions = [.truncatesLastVisibleLine, .usesLineFragmentOrigin]
            var expectedTextRect = string.boundingRect(with: lineRect.size, options: options)

            let offsetFromLastCharacter: CGFloat = 8
            let drawingArea = NSRect(
                x: lastPosition + offsetFromLastCharacter,
                y: lineRect.origin.y + containerOrigin.y,
                width: lineRect.width - lastPosition - offsetFromLastCharacter,
                height: lineRect.height
            )

            let textPadding = NSEdgeInsets(top: 1, left: 24, bottom: 0, right: 8)
            let idealTargetWidth = expectedTextRect.width + textPadding.left + textPadding.right
            let targetWidth = min(idealTargetWidth, drawingArea.width)

            guard drawingArea.size.width > 40 else {
                return
            }

            let errorViewFrame = CGRect(
                x: drawingArea.origin.x + (drawingArea.width - targetWidth),
                y: drawingArea.origin.y,
                width: targetWidth,
                height: drawingArea.height
            )

            expectedTextRect.origin.y = drawingArea.origin.y
            expectedTextRect.size.height = drawingArea.size.height

            NSColor.red.withAlphaComponent(0.33).setFill()
            NSBezierPath(roundedRect: errorViewFrame, xRadius: 4, yRadius: 4).fill()

            string.draw(with: {
                var textRect = errorViewFrame
                textRect.size.width -= (textPadding.left + textPadding.right)
                textRect.origin.x += textPadding.left
                textRect.origin.y += textPadding.top
                return textRect
            }(), options: options)

            let image = NSImage(systemSymbolName: "xmark.octagon.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: [.white, .red]))
            let iconRect = NSRect(
                x: errorViewFrame.origin.x + 4,
                y: errorViewFrame.origin.y + 1,
                width: 17,
                height: 15
            )
            image?.draw(in: iconRect)
        }
    }
}

enum RichTextViewUnderlyingStyle: Int {
    case searchResult = 11
    case searchResultHighlighted = 12
    case more = 13
    case error = 14
}

private let focusedColor = Palette.yellow
private let highlightColor = Palette.yellow

private extension Palette {
    @available(iOS 13.0, tvOS 13.0, *)
    static var yellow: UXColor {
        UXColor.dynamic(light: Palette.darkYellow, dark: Palette.darkYellow)
    }
    private static let lightYellow = UXColor(red: 254.0/255.0, green: 248.0/255.0, blue: 106.0/255.0, alpha: 1.0)
    private static let darkYellow = UXColor(red: 254.0/255.0, green: 249.0/255.0, blue: 57.0/255.0, alpha: 1.0)

    @available(iOS 13.0, tvOS 13.0, *)
    static var searchBackground: UXColor {
        UXColor.dynamic(light: NSColor.textColor.withAlphaComponent(0.15), dark: NSColor.textColor.withAlphaComponent(0.25))
    }
}

private extension NetworkLogger.DecodingError {
    var shortDescription: String {
        switch self {
        case .typeMismatch(let type, _):
            return "Expected \(type)"
        case .valueNotFound(_, _):
            return "Value missing"
        case .keyNotFound(let codingKey, _):
            return "Key \"\(codingKey.debugDescription)\" not found"
        case .dataCorrupted:
            return "Data corrupted"
        case .unknown:
            return "Unknown error"
        }
    }
}

#endif
