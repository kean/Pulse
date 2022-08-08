// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

enum JSONElement {
    case punctuation
    case key
    case valueString
    case valueOther
    case null
}

protocol JSONRenderer: AnyObject {
    func append(_ string: String, element: JSONElement, error: NetworkLogger.DecodingError?)
    func indent(count: Int)
    func newline()
}

final class HTMLJSONRender: JSONRenderer {
    private var output = ""

    func append(_ string: String, element: JSONElement, error: NetworkLogger.DecodingError?) {
        let htmlClass = error == nil ? getClass(for: element) : "err"
        output.append("<span class=\"\(htmlClass)\">\(string)</span>")
    }

    func indent(count: Int) {
        output.append(String(repeating: " ", count: count))
    }

    func newline() {
        output.append("\n")
    }

    func make() -> String {
        output
    }
}

private func getClass(for element: JSONElement) -> String {
    switch element {
    case .punctuation: return "p"
    case .key: return "k"
    case .valueString: return "s"
    case .valueOther: return "o"
    case .null: return "n"
    }
}

final class JSONPrinter {
    private let renderer: JSONRenderer
    private var indentation = 0
    private var error: NetworkLogger.DecodingError?
    private var codingPath: [NetworkLogger.DecodingError.CodingKey] = []

    init(renderer: JSONRenderer) {
        self.renderer = renderer
    }

    func render(json: Any, error: NetworkLogger.DecodingError?) {
        self.error = error
        print(json: json, isFree: true)
    }

    private func print(json: Any, isFree: Bool) {
        func _print(json: Any, key: NetworkLogger.DecodingError.CodingKey, isFree: Bool) {
            codingPath.append(key)
            print(json: json, isFree: isFree)
            _ = codingPath.popLast()
        }

        switch json {
        case let object as [String: Any]:
            if isFree {
                indent()
            }
            append("{", .punctuation)
            newline()
            let keys = object.keys.sorted()
            for key in keys {
                indent()
                append("  \"\(key)\"", .key)
                append(": ", .punctuation)
                indentation += 2
                _print(json: object[key]!, key: .string(key), isFree: false)
                indentation -= 2
                if key != keys.last {
                    append(",", .punctuation)
                }
                newline()
            }
            indent()
            append("}", .punctuation)
        case let object as String:
            append("\"\(object)\"", .valueString)
        case let array as [Any]:
            if array.contains(where: { $0 is [String: Any] }) {
                append("[\n", .punctuation)
                indentation += 2
                for index in array.indices {
                    _print(json: array[index], key: .int(index), isFree: true)
                    if index < array.endIndex - 1 {
                        append(",", .punctuation)
                    }
                    newline()
                }
                indentation -= 2
                indent()
                append("]", .punctuation)
            } else {
                append("[", .punctuation)
                for index in array.indices {
                    _print(json: array[index], key: .int(index), isFree: true)
                    if index < array.endIndex - 1 {
                        append(", ", .punctuation)
                    }
                }
                append("]", .punctuation)
            }
        case let number as NSNumber:
            if number === kCFBooleanTrue {
                append("true", .valueOther)
            } else if number === kCFBooleanFalse {
                append("false", .valueOther)
            } else {
                append("\(number)", .valueOther)
            }
        default:
            if json is NSNull {
                append("null", .null)
            } else {
                append("\(json)", .valueOther)
            }
        }
    }

    func append(_ string: String, _ element: JSONElement) {
        var error: NetworkLogger.DecodingError?
        if codingPath == self.error?.context?.codingPath {
            error = self.error
            self.error = nil
        }
        renderer.append(string, element: element, error: error)
    }

    func indent() {
        renderer.indent(count: indentation)
    }

    func newline() {
        renderer.newline()
    }
}

#if os(iOS) || os(macOS) || os(tvOS)

struct JSONColors {
    static let punctuation = UXColor.dynamic(
        light: .init(red: 113.0/255.0, green: 128.0/255.0, blue: 141.0/255.0, alpha: 1.0),
        dark: .init(red: 108.0/255.0, green: 121.0/255.0, blue: 134.0/255.0, alpha: 1.0)
    )
    static let key = UXColor.label
    static let valueString = Palette.red
    static let valueOther = UXColor.dynamic(
        light: .init(red: 28.0/255.0, green: 0.0/255.0, blue: 207.0/255.0, alpha: 1.0),
        dark: .init(red: 208.0/255.0, green: 191.0/255.0, blue: 105.0/255.0, alpha: 1.0)
    )
    static let null = Palette.pink
}

final class AttributedStringJSONRenderer: JSONRenderer {
    private let output = NSMutableAttributedString()
    private let fontSize: CGFloat
    private let lineHeight: CGFloat

    private var attributes: [JSONElement: [NSAttributedString.Key: Any]] = [
        .punctuation: [.foregroundColor: JSONColors.punctuation],
        .key: [.foregroundColor: JSONColors.key],
        .valueString: [.foregroundColor: JSONColors.valueString],
        .valueOther: [.foregroundColor: JSONColors.valueOther],
        .null: [.foregroundColor: JSONColors.null]
    ]

    init(fontSize: CGFloat, lineHeight: CGFloat) {
        self.fontSize = fontSize
        self.lineHeight = lineHeight
    }

    func append(_ string: String, element: JSONElement, error: NetworkLogger.DecodingError?) {
        var attributes = self.attributes[element]!
        if let error = error {
            attributes[.backgroundColor] = UXColor.red
            attributes[.foregroundColor] = UXColor.white
            attributes[.decodingError] = error
        }
        output.append(string, attributes)
    }

    func indent(count: Int) {
        append(String(repeating: " ", count: count), element: .punctuation, error: nil)
    }

    func newline() {
        output.append("\n")
    }

    func make() -> NSAttributedString {
        output.addAttributes([
            .font: UXFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular),
            .paragraphStyle: NSParagraphStyle.make(lineHeight: lineHeight)
        ])
        return output
    }
}

extension NSAttributedString.Key {
    static let decodingError = NSAttributedString.Key(rawValue: "com.github.kean.pulse.decoding-error-key")
}

#endif
