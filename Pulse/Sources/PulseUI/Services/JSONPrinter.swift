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

@available(iOS 13.0, tvOS 14.0, *)
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
    static let punctuation = UXColor.dynamic(
        light: .init(red: 113.0/255.0, green: 128.0/255.0, blue: 141.0/255.0, alpha: 1.0),
        dark: .init(red: 108.0/255.0, green: 121.0/255.0, blue: 134.0/255.0, alpha: 1.0)
    )
    static let key = UXColor.label
    static let valueString = Pallete.red
    static let valueOther = UXColor.dynamic(
        light: .init(red: 28.0/255.0, green: 0.0/255.0, blue: 207.0/255.0, alpha: 1.0),
        dark: .init(red: 208.0/255.0, green: 191.0/255.0, blue: 105.0/255.0, alpha: 1.0)
    )
    static let null = Pallete.pink
}

@available(iOS 13, tvOS 14.0, *)
final class AttributedStringJSONRenderer: JSONRenderer {
    private let output = NSMutableAttributedString()
    private let fontSize: CGFloat
    private let lineHeight: CGFloat
    
    init(fontSize: CGFloat = 11, lineHeight: CGFloat = 17) {
        self.fontSize = fontSize
        self.lineHeight = lineHeight
    }
    
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
        ps.minimumLineHeight = lineHeight
        ps.maximumLineHeight = lineHeight
        
        output.addAttributes([
            .font: UXFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular),
            .paragraphStyle: ps
        ])
        return output
    }
}

#endif
