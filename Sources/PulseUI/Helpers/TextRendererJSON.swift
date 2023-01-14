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
    private let spaces = 2

    // Temporary state (one-shot, doesn't reset)
    private var indentation = 0
    private var index = 0
    private var codingPath: [NetworkLogger.DecodingError.CodingKey] = []
    private var elements: [(NSRange, JSONElement)] = []
    private var errorRange: NSRange?
    private var string = ""

    init(json: Any, error: NetworkLogger.DecodingError? = nil, options: TextRenderer.Options = .init()) {
        self.options = options
        self.helper = TextHelper()
        self.json = json
        self.error = error
    }

    func render() -> NSAttributedString {
        print(json: json, isFree: true)

        let output = NSMutableAttributedString(string: string, attributes: helper.attributes(role: .body2, style: .monospaced, color: color(for: .key)))
        for (range, element) in elements {
            output.addAttribute(.foregroundColor, value: color(for: element), range: range)
        }
        if let range = errorRange {
            output.addAttributes(makeErrorAttributes(), range: range)
        }
        return output
    }

    private func color(for element: JSONElement) -> UXColor {
        if options.color == .monochrome {
            switch element {
            case .punctuation: return UXColor.secondaryLabel
            case .key: return UXColor.label
            case .valueString: return UXColor.label
            case .valueOther: return UXColor.label
            case .null: return UXColor.label
            }
        } else {
            switch element {
            case .punctuation: return JSONColors.punctuation
            case .key: return JSONColors.key
            case .valueString: return JSONColors.valueString
            case .valueOther: return JSONColors.valueOther
            case .null: return JSONColors.null
            }
        }
    }

    // MARK: - Walk JSON

    private func print(json: Any, isFree: Bool) {
        func _print(json: Any, key: NetworkLogger.DecodingError.CodingKey, isFree: Bool) {
            codingPath.append(key)
            print(json: json, isFree: isFree)
            codingPath.removeLast()
        }

        switch json {
        case let object as [String: Any]:
            if isFree {
                indent()
            }
            append("{", .punctuation)
            newline()
            let keys = object.keys.sorted()
            for index in keys.indices {
                let key = keys[index]
                indent()
                append("\(String(repeating: " ", count: spaces))\"\(key)\"", .key)
                append(": ", .punctuation)
                indentation += 1
                _print(json: object[key]!, key: .string(key), isFree: false)
                indentation -= 1
                if index < keys.endIndex - 1 {
                    append(",", .punctuation)
                }
                newline()
            }
            indent()
            append("}", .punctuation)
        case let string as String:
            append("\"\(string)\"", .valueString)
        case let array as [Any]:
            if array is [String] || array is [Int] || array is [NSNumber] {
                append("[", .punctuation)
                for index in array.indices {
                    _print(json: array[index], key: .int(index), isFree: true)
                    if index < array.endIndex - 1 {
                        append(", ", .punctuation)
                    }
                }
                append("]", .punctuation)
            } else {
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

    private var previousElement: JSONElement?

    private func append(_ string: String, _ element: JSONElement) {
        let length = string.utf16.count
        self.string += string

        if element != .key { // Style for keys is the default one
            if previousElement == element { // Coalesce the same elements
                elements[elements.endIndex - 1].0.length += length
            } else {
                elements.append((NSRange(location: index, length: length), element))
            }
        }
        previousElement = element

        if let error = self.error, errorRange == nil, codingPath == error.context?.codingPath {
            errorRange = NSRange(location: index, length: length)
        }

        index += length
    }

    private func indent() {
        append(String(repeating: " ", count: indentation * spaces), .punctuation)
    }

    private func newline() {
        append("\n", .punctuation)
    }

    // MARK: Error

    func makeErrorAttributes() -> [NSAttributedString.Key: Any] {
        guard let error = error else {
            return [:]
        }
        return [
            .backgroundColor: options.color == .monochrome ? UXColor.label : UXColor.red,
            .foregroundColor: UXColor.white,
            .decodingError: error,
            .link: {
                var components = URLComponents()
                components.scheme = "pulse"
                components.path = "tooltip"
                components.queryItems = [
                    URLQueryItem(name: "title", value: "Decoding Error"),
                    URLQueryItem(name: "message", value: error.debugDescription)
                ]
                return components.url as Any
            }(),
            .underlineColor: UXColor.clear
        ]
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
