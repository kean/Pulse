// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

final class TextRendererJSON {
    // Input
    private let json: Any
    private var error: NetworkLogger.DecodingError?

    // Settings
    private let options: TextRenderer.Options
    private let helper: TextHelper
    private let attributes: [JSONElement: [NSAttributedString.Key: Any]]

    // Temporary state (one-shot, doesn't reset)
    private var indentation = 0
    private var codingPath: [NetworkLogger.DecodingError.CodingKey] = []
    private var string = NSMutableAttributedString()

    init(json: Any, error: NetworkLogger.DecodingError? = nil, options: TextRenderer.Options = .init()) {
        self.options = options
        self.helper = TextHelper()
        self.json = json
        self.error = error

        if options.color == .monochrome {
            attributes = [
                .punctuation: [.foregroundColor: UXColor.secondaryLabel],
                .key: [.foregroundColor: UXColor.label],
                .valueString: [.foregroundColor: UXColor.label],
                .valueOther: [.foregroundColor: UXColor.label],
                .null: [.foregroundColor: UXColor.label]
            ]
        } else {
            attributes = [
                .punctuation: [.foregroundColor: JSONColors.punctuation],
                .key: [.foregroundColor: JSONColors.key],
                .valueString: [.foregroundColor: JSONColors.valueString],
                .valueOther: [.foregroundColor: JSONColors.valueOther],
                .null: [.foregroundColor: JSONColors.null]
            ]
        }
    }

    func render() -> NSAttributedString {
        guard string.length == 0 else {
            assertionFailure("TextRendererJSON is a one-shot object")
            return string
        }
        print(json: json, isFree: true)
        string.addAttributes(helper.attributes(role: .body2, style: .monospaced, color: nil))
        return string
    }

    // MARK: - Walk JSON

    private let spaces = 2

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
                append("\(String(repeating: " ", count: spaces))\"\(key)\"", .key)
                append(": ", .punctuation)
                indentation += 1
                _print(json: object[key]!, key: .string(key), isFree: false)
                indentation -= 1
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
                indentation += 1
                for index in array.indices {
                    _print(json: array[index], key: .int(index), isFree: true)
                    if index < array.endIndex - 1 {
                        append(",", .punctuation)
                    }
                    newline()
                }
                indentation -= 1
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

    // MARK: - Modify String

    private func append(_ string: String, _ element: JSONElement) {
        var error: NetworkLogger.DecodingError?
        if codingPath == self.error?.context?.codingPath {
            error = self.error
            self.error = nil
        }

        var attributes = self.attributes[element]!
        if let error = error {
            attributes[.backgroundColor] = options.color == .monochrome ? UXColor.label : UXColor.red
            attributes[.foregroundColor] = UXColor.white
            attributes[.decodingError] = error
            attributes[.link] = {
                var components = URLComponents()
                components.scheme = "pulse"
                components.path = "tooltip"
                components.queryItems = [
                    URLQueryItem(name: "title", value: "Decoding Error"),
                    URLQueryItem(name: "message", value: error.debugDescription)
                ]
                return components.url
            }()
            attributes[.underlineColor] = UXColor.clear
        }
        self.string.append(string, attributes)
    }

    private func indent() {
        append(String(repeating: " ", count: indentation * spaces), .punctuation)
    }

    private func newline() {
        string.append("\n")
    }
}

private struct JSONColors {
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

extension NSAttributedString.Key {
    static let decodingError = NSAttributedString.Key(rawValue: "com.github.kean.pulse.decoding-error-key")
}

private enum JSONElement {
    case punctuation
    case key
    case valueString
    case valueOther
    case null
}
