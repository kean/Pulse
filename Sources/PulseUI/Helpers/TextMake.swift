// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse


#warning("TODO: do we need this?")
/// A high-level convenience API for creating attributed strings using the
/// underlying ``TextRenderer``.
struct TextMake {
    private let output = NSMutableAttributedString()
    private let renderer: TextRenderer

    init(renderer: TextRenderer = .init()) {
        self.renderer = renderer
    }

    @discardableResult func subheadline(_ string: String) -> TextMake {
        append(renderer.render(subheadline: string))
    }

    @discardableResult func spacer() -> TextMake {
        append(renderer.spacer())
    }

    @discardableResult func json(_ json: Any, color: UXColor? = nil) -> TextMake {
        var string = renderer.render(json: json)
        if let color = color {
            string = string.with(.foregroundColor, color)
        }
        return append(string)
    }

    @discardableResult func pre(_ string: String, color: UXColor? = nil) -> TextMake {
        append(renderer.render(string, role: .body2, style: .monospaced, color: color ?? .label))
    }

    @discardableResult func string(_ string: NSAttributedString) -> TextMake {
        append(string)
    }

    @discardableResult func newline() -> TextMake {
        append(NSAttributedString(string: "\n"))
    }

    private func append(_ string: NSAttributedString) -> TextMake {
        output.append(string)
        return self
    }

    func make() -> NSAttributedString {
        output
    }
}

struct NetworkContent: OptionSet {
    let rawValue: Int16
    init(rawValue: Int16) { self.rawValue = rawValue }

    static let header = NetworkContent(rawValue: 1 << 0)
    static let requestComponents = NetworkContent(rawValue: 1 << 1)
    static let requestQueryItems = NetworkContent(rawValue: 1 << 2)
    static let errorDetails = NetworkContent(rawValue: 1 << 3)
    static let originalRequestHeaders = NetworkContent(rawValue: 1 << 4)
    static let currentRequestHeaders = NetworkContent(rawValue: 1 << 5)
    static let requestOptions = NetworkContent(rawValue: 1 << 6)
    static let requestBody = NetworkContent(rawValue: 1 << 7)
    static let responseHeaders = NetworkContent(rawValue: 1 << 8)
    static let responseBody = NetworkContent(rawValue: 1 << 9)

    static let all: NetworkContent = [
        header, requestComponents, requestQueryItems, errorDetails, originalRequestHeaders, currentRequestHeaders, requestOptions, requestBody, responseHeaders, responseBody
    ]
}
