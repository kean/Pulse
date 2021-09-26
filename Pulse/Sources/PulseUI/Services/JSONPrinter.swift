// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import Foundation
import PulseCore
import CoreData
import SwiftUI
import PulseCore

enum JSONElement {
    case punctuation
    case key
    case valueString
    case valueOther
    case null
}

protocol JSONRenderer: AnyObject {
    func append(_ string: String, element: JSONElement)
    func indent(count: Int)
    func newline()
}

final class HTMLJSONRender: JSONRenderer {
    private var output = ""

    func append(_ string: String, element: JSONElement) {
        output.append("<span class=\"\(getClass(for: element))\">\(string)</span>")
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

@available(iOS 13, tvOS 14.0, *)
final class JSONPrinter {
    private let renderer: JSONRenderer
    private var indentation = 0

    init(renderer: JSONRenderer) {
        self.renderer = renderer
    }

    func render(json: Any) {
        print(json: json, isFree: true)
    }

    private func print(json: Any, isFree: Bool) {
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
                print(json: object[key]!, isFree: false)
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
        case let array as Array<Any>:
            if array.contains(where: { $0 is [String: Any] }) {
                append("[\n", .punctuation)
                indentation += 2
                for index in array.indices {
                    print(json: array[index], isFree: true)
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
                    print(json: array[index], isFree: true)
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
        renderer.append(string, element: element)
    }

    func indent() {
        renderer.indent(count: indentation)
    }

    func newline() {
        renderer.newline()
    }
}

#if os(iOS) || os(macOS) || os(tvOS)

@available(iOS 13, tvOS 14.0, *)
struct JSONColors {
    static let punctuation = UXColor.label.withAlphaComponent(0.7)
    static let key = UXColor.label
    static let valueString = UXColor.systemRed
    static let valueOther = UXColor.systemBlue
    static let null = UXColor.systemPurple
}


@available(iOS 13, tvOS 14.0, *)
final class AttributedStringJSONRenderer: JSONRenderer {
    private let output = NSMutableAttributedString()

    func append(_ string: String, element: JSONElement) {
        output.append(string, attributes(for: element))
    }

    func indent(count: Int) {
        append(String(repeating: " ", count: count), element: .punctuation)
    }

    func newline() {
        output.append("\n")
    }

    private func attributes(for element: JSONElement) -> [NSAttributedString.Key: Any] {
        switch element {
        case .punctuation: return [.foregroundColor: JSONColors.punctuation]
        case .key: return [.foregroundColor: JSONColors.key]
        case .valueString: return [.foregroundColor: JSONColors.valueString]
        case .valueOther: return [.foregroundColor: JSONColors.valueOther]
        case .null: return [.foregroundColor: JSONColors.null]
        }
    }

    func make() -> NSAttributedString {
        let ps = NSMutableParagraphStyle()
        ps.minimumLineHeight = 17
        ps.maximumLineHeight = 17
        
        output.addAttributes([
            .font: UXFont.monospacedSystemFont(ofSize: FontSize.body, weight: .regular),
            .paragraphStyle: ps
        ])
        return output
    }
}

#endif
