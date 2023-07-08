// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse

#if os(macOS)
import AppKit
#endif

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
    private var elements: [(NSRange, JSONElement, JSONContainerNode?)] = []
    private var errorRange: NSRange?
    private var string = ""

    init(json: Any, error: NetworkLogger.DecodingError? = nil, options: TextRenderer.Options = .init()) {
        self.options = options
        self.helper = TextHelper()
        self.json = json
        self.error = error
    }

    func render() -> NSAttributedString {
        render(json: json, isFree: true)

        let output = NSMutableAttributedString(string: string, attributes: helper.attributes(role: .body2, style: .monospaced, color: color(for: .key)))
        for (range, element, node) in elements {
            output.addAttribute(.foregroundColor, value: color(for: element), range: range)
#if os(macOS)
            if let node = node {
                output.addAttribute(.node, value: node, range: range)
                output.addAttribute(.cursor, value: NSCursor.pointingHand, range: range)
            }
#endif
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

    private func render(json: Any, isFree: Bool) {
        switch json {
        case let object as [String: Any]:
            if isFree {
                indent()
            }
            renderObject(object)
        case let string as String:
            renderString(string)
        case let array as [Any]:
            renderArray(array)
        case let number as NSNumber:
            renderNumber(number)
        default:
            if json is NSNull {
                append("null", .null)
            } else {
                append("\(json)", .valueOther)
            }
        }
    }

    private func render(json: Any, key: NetworkLogger.DecodingError.CodingKey, isFree: Bool) {
        codingPath.append(key)
        render(json: json, isFree: isFree)
        codingPath.removeLast()
    }

    private func renderObject(_ object: [String: Any]) {
        let node = JSONContainerNode(kind: .object, json: object)
        append("{", .punctuation, node)
        newline()
        let keys = object.keys.sorted()
        for index in keys.indices {
            let key = keys[index]
            indent()
            append(String(repeating: " ", count: spaces), .punctuation)
            append("\"\(key)\"", .key)
            append(": ", .punctuation)
            indentation += 1
            render(json: object[key]!, key: .string(key), isFree: false)
            indentation -= 1
            if index < keys.endIndex - 1 {
                append(",", .punctuation)
            }
            newline()
        }
        indent()
        append("}", .punctuation, node)
    }

    private func renderArray(_ array: [Any]) {
        let node = JSONContainerNode(kind: .array, json: array)
        if array is [String] || array is [Int] || array is [NSNumber] {
            append("[", .punctuation, node)
            for index in array.indices {
                render(json: array[index], key: .int(index), isFree: true)
                if index < array.endIndex - 1 {
                    append(", ", .punctuation)
                }
            }
            append("]", .punctuation, node)
        } else {
            append("[", .punctuation, node)
            append("\n", .punctuation)
            indentation += 1
            for index in array.indices {
                render(json: array[index], key: .int(index), isFree: true)
                if index < array.endIndex - 1 {
                    append(",", .punctuation)
                }
                newline()
            }
            indentation -= 1
            indent()
            append("]", .punctuation, node)
        }
    }

    private func renderString(_ string: String) {
        append("\"\(string)\"", .valueString)
    }

    private func renderNumber(_ number: NSNumber) {
        if number === kCFBooleanTrue {
            append("true", .valueOther)
        } else if number === kCFBooleanFalse {
            append("false", .valueOther)
        } else {
            append("\(number)", .valueOther)
        }
    }

    // MARK: - Modify String

    private var previousElement: JSONElement?

    private func append(_ string: String, _ element: JSONElement, _ node: JSONContainerNode? = nil) {
        let length = string.utf16.count
        self.string += string

        if element != .key { // Style for keys is the default one
            if previousElement == element, element != .punctuation { // Coalesce the same elements
                elements[elements.endIndex - 1].0.length += length
            } else {
                elements.append((NSRange(location: index, length: length), element, node))
            }
        }
        previousElement = element

        if let error = self.error, errorRange == nil, codingPath == error.context?.codingPath {
            switch error {
            case .keyNotFound:
                // Display error on the first key in the object regardless of what it is
                if element == .key {
                    errorRange = NSRange(location: index, length: length)
                }
            default:
                errorRange = NSRange(location: index, length: length)
            }
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
#if PULSE_STANDALONE_APP
        return [
            .decodingError: error,
            .underlineColor: UXColor.red,
            .underlineStyle: RichTextViewUnderlyingStyle.error.rawValue,
            .cursor: NSCursor.pointingHand
        ]
#else
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
#endif
    }
}

struct JSONColors {
    static let punctuation = UXColor.dynamic(
        light: .init(red: 113.0/255.0, green: 128.0/255.0, blue: 141.0/255.0, alpha: 1.0),
        dark: .init(red: 113.0/255.0, green: 128.0/255.0, blue: 141.0/255.0, alpha: 1.0)
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
    static let node = NSAttributedString.Key(rawValue: "com.github.kean.pulse.json-container-node")
}

enum JSONElement {
    case punctuation
    case key
    case valueString
    case valueOther
    case null
}

final class JSONContainerNode {
    enum Kind {
        case object
        case array
    }

    let kind: Kind
    let json: Any
    var isExpanded = true
    var expanded: NSAttributedString?

    init(kind: Kind, json: Any) {
        self.kind = kind
        self.json = json
    }

    var openingCharacter: String {
        switch kind {
        case .object: return "{"
        case .array: return "["
        }
    }

    var closingCharacter: String {
        switch kind {
        case .object: return "}"
        case .array: return "]"
        }
    }
}
