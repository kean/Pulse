// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#warning("TODO: add PDF export and test printing")
#warning("TODO: add metrics and cookies and other missing values from summary")
#warning("TODO: remove FontSize setting from ConsoleTextView for now")
#warning("TODO: do other styles work?")

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

#if !os(watchOS)
import PDFKit
#endif

/// Renders console messages as attributed strings.
final class TextRenderer {
    struct Options {
        var networkContent: RenteredNetworkContent = [.errorDetails, .requestBody, .responseBody]
        var isMonocrhome = true
        var isBodySyntaxHighlightingEnabled = true
        var isBodyExpanded = false
        var bodyCollapseLimit = 20
        var fontSize: CGFloat = 15
    }

    private var options: Options
    private var helpers: TextHelpers
    private var index = 0

    init(options: Options = .init()) {
        self.options = options
        self.helpers = TextHelpers(options: options)
    }

#warning("TODO: this should not be TextRenderer responsbility")
    var expanded: Set<Int> = []

    func render(_ entities: [NSManagedObject], options: Options = .init()) -> NSAttributedString {
        if let entities = entities as? [LoggerMessageEntity] {
            return render(entities, options: options)
        } else if let entities = entities as? [NetworkTaskEntity] {
            return render(entities, options: options)
        } else {
            return NSAttributedString(string: "Unsupported entities")
        }
    }

#warning("TODO: remove")
    @available(*, deprecated, message: "Deprecated")
    func render(_ entities: [NetworkTaskEntity], options: Options = .init()) -> NSAttributedString {
        prepare(options: options)
        return joined(entities.map(render))
    }
    
#warning("TODO: remove")
    @available(*, deprecated, message: "Deprecated")
    func render(_ entities: [LoggerMessageEntity], options: Options = .init()) -> NSAttributedString {
        prepare(options: options)
        return joined(entities.map(render))
    }

    private func prepare(options: Options) {
        self.options = options
        self.helpers = TextHelpers(options: options)
        self.index = 0
    }

    private func joined(_ strings: [NSAttributedString]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for string in strings {
            output.append(string)
            output.append("\n", helpers.spacerAttributes)
        }
        return output
    }

    func render(_ message: LoggerMessageEntity) -> NSAttributedString {
        defer { index += 1 }

        if let task = message.task {
            return render(task)
        }

        let text = NSMutableAttributedString()

        // Title
        let viewModel = ConsoleMessageViewModel(message: message)
        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        text.append(viewModel.titleForTextRepresentation + "\n", helpers.captionAttributes)

        // Text
        let textAttributes = helpers.textAttributes[level]!
        text.append(message.text + "\n", textAttributes)

        return text
    }

    func render(_ task: NetworkTaskEntity) -> NSAttributedString {
        defer { index += 1 }

#warning("TODO: refactor remainig")

        let text = NSMutableAttributedString()

        let state = task.state

        let tintColor: UXColor = {
            switch state {
            case .pending: return .systemYellow
            case .success: return .systemGreen
            case .failure: return Palette.red
            }
        }()

        let topViewModel = ConsoleNetworkRequestViewModel(task: task)
        let title = topViewModel.titleForTextRepresentation

        text.append(title + "\n", {
            var attributes = helpers.captionAttributes
            if !options.isMonocrhome {
                attributes[.foregroundColor] = tintColor
            }
            return attributes
        }())

        func append(section: KeyValueSectionViewModel?) {
            guard let section = section else { return }
            text.append("\n", helpers.spacerAttributes)
            text.append(render(section))
        }

        let url = task.url.flatMap(URL.init) ?? URL(string: "invalid-url")!

        text.append(url.absoluteString + "\n", {
            var attributes = helpers.textAttributes[.debug]!
            attributes[.font] = UXFont.systemFont(ofSize: options.fontSize, weight: .medium)
            if !options.isMonocrhome {
                attributes[.foregroundColor] = tintColor
            }
            return attributes
        }())

        let content = options.networkContent

        if content.contains(.requestComponents) {
            append(section: .makeComponents(for: url))
        }
        if content.contains(.requestQueryItems) {
            append(section: .makeQueryItems(for: url))
        }
        if content.contains(.requestOptions), let request = task.originalRequest {
            append(section: .makeParameters(for: request))
        }
        if content.contains(.errorDetails) {
            append(section: .makeErrorDetails(for: task))
        }
        if let originalRequest = task.originalRequest {
            if content.contains(.originalRequestHeaders) {
                append(section: .makeHeaders(title: "Original Request Headers", headers: originalRequest.headers))
            }
            if content.contains(.currentRequestHeaders), let currentRequest = task.currentRequest {
                if originalRequest.headers == currentRequest.headers {
                    text.append("Same as Original", [
                        .font: UXFont.systemFont(ofSize: TextSize.body, weight: .regular),
                        .foregroundColor: UXColor.secondaryLabel,
                        .paragraphStyle: helpers.bodParagraphStyle
                    ])
                } else {
                    append(section: .makeHeaders(title: "Current Request Headers", headers: currentRequest.headers))
                }
            }
            if content.contains(.requestBody), let data = task.requestBody?.data, !data.isEmpty {
                text.append("\n", helpers.spacerAttributes)
                text.append("Request Body\n", helpers.captionAttributes)
                text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
                text.append("\n", helpers.detailsAttributes)
            }
        }
        if content.contains(.responseHeaders), let response = task.response {
            append(section: .makeHeaders(title: "Response Headers", headers: response.headers))
        }
        if content.contains(.responseBody), let data = task.responseBody?.data, !data.isEmpty {
            text.append("\n", helpers.spacerAttributes)
            text.append("Response Body\n", helpers.captionAttributes)
            text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
            text.append("\n", helpers.detailsAttributes)
        }
        return text
    }

#warning("TODO: rework this")
    private func renderNetworkTaskBody(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: _renderNetworkTaskBody(data, contentType: contentType, error: error))
        if !options.isBodySyntaxHighlightingEnabled {
            text.addAttributes([
                .foregroundColor: UXColor.label
            ])
        }
        if !options.isBodyExpanded && !expanded.contains(index) {
            let string = text.string as NSString
            var counter = 0
            var index = 0
            while index < string.length, counter < options.bodyCollapseLimit {
                if string.character(at: index) == 0x0a {
                    counter += 1
                }
                index += 1
            }
            if index != string.length {
                do { // trim newlines
                    while index > 1, string.character(at: index - 1) == 0x0a {
                        index -= 1
                    }
                }
                let text = NSMutableAttributedString(attributedString: text.attributedSubstring(from: NSRange(location: 0, length: index)))
                var attributes = helpers.detailsAttributes
                attributes[.foregroundColor] = UXColor.systemBlue
                attributes[.link] = URL(string: "pulse://expand/\(self.index)")
                attributes[.underlineColor] = UXColor.clear
                text.append("\n", helpers.spacerAttributes)
                text.append("\nExpand ▷", attributes)
                return text
            }
        }
        return text
    }

    private func _renderNetworkTaskBody(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?) -> NSAttributedString {
        let fontSize = options.fontSize - 3
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            let renderer = AttributedStringJSONRenderer(fontSize: fontSize, lineHeight: geLineHeight(for: Int(fontSize)))
            let printer = JSONPrinter(renderer: renderer)
            printer.render(json: json, error: error)
            return renderer.make()
        } else if let string = String(data: data, encoding: .utf8) {
            if contentType?.isEncodedForm ?? false, let components = decodeQueryParameters(form: string) {
                return components.asAttributedString()
            } else if contentType?.isHTML ?? false {
                return HTMLPrettyPrint(string: string, fontSize: Int(fontSize)).render()
            }
            return NSAttributedString(string: string, attributes: helpers.textAttributes[.debug]!)
        } else {
            let message = "Data \(ByteCountFormatter.string(fromByteCount: Int64(data.count)))"
            return NSAttributedString(string: message, attributes: helpers.textAttributes[.debug]!)
        }
    }

    #warning("TODO: remove")
    @available(*, deprecated, message: "Deprecated")
    private func decodeQueryParameters(form string: String) -> KeyValueSectionViewModel? {
        let string = "https://placeholder.com/path?" + string
        guard let components = URLComponents(string: string),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return nil
        }
        return KeyValueSectionViewModel.makeQueryItems(for: queryItems)
    }

    func render(_ section: KeyValueSectionViewModel, isMonospaced: Bool = true) -> NSAttributedString {
        let string = NSMutableAttributedString()
        string.append(section.title + "\n", helpers.captionAttributes)
        string.append(render(section.items, color: section.color, isMonospaced: isMonospaced))
        return string
    }

    func render(_ values: [(String, String?)]?, color: Color, isMonospaced: Bool = true) -> NSAttributedString {
        let string = NSMutableAttributedString()
        guard let values = values, !values.isEmpty else {
            return string
        }
        var keyAttributes: [NSAttributedString.Key: Any] = [
            .font: isMonospaced ? UXFont.monospacedSystemFont(ofSize: TextSize.mono, weight: .semibold) : UXFont.systemFont(ofSize: TextSize.caption, weight: .semibold),
            .foregroundColor: UXColor.label,
            .paragraphStyle: helpers.monoParagraphStyle,
        ]
        if #available(iOS 14, tvOS 14, *), !options.isMonocrhome {
            keyAttributes[.foregroundColor] = options.isMonocrhome ? UXColor.label : UXColor(color)
        }
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: isMonospaced ? UXFont.monospacedSystemFont(ofSize: TextSize.mono, weight: .regular) : UXFont.systemFont(ofSize: TextSize.caption, weight: .regular),
            .foregroundColor: UXColor.label,
            .paragraphStyle: helpers.monoParagraphStyle,
        ]
        for (key, value) in values {
            string.append(key, keyAttributes)
            string.append(": \(value ?? "–")\n", valueAttributes)
        }
        return string
    }

    // MARK: - Convert to HTML/PDF

#warning("TODO: add author, date, and other meta attributes + link to Pulse (?)")
    static func html(from string: NSAttributedString) throws -> Data {
        let range = NSRange(location: 0, length: string.length)
        let data = try string.data(from: range, documentAttributes: [
            .documentType: NSAttributedString.DocumentType.html
        ])
        guard var html = String(data: data, encoding: .utf8) else {
            return data
        }
        func insert(_ string: String, at index: String.Index) {
            html.insert(contentsOf: "\n\(string)", at: index)
        }
        if let range = html.firstRange(of: "<head>") {
            insert(#"<meta name="viewport" content="width=device-width, initial-scale=1">"#, at: range.upperBound)
        }
        if let range = html.firstRange(of: "<style type=\"text/css\">") {
            insert(#"body { word-wrap: break-word; }"#, at: range.upperBound)
        }
        return html.data(using: .utf8) ?? data
    }

#warning("TODO: imporve and enable sharing (in diff parts of the app) + check printing + monochrome always")
#warning("TODO: check if we can render as a single page if that even makes sense")
    /// Renderes the given attributed string as PDF
#if canImport(UIKit)
    static func pdf(from string: NSAttributedString) throws -> Data {
        let formatter = UISimpleTextPrintFormatter(attributedText: string)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageSize = CGSize(width: 612, height: 792) // US letter size
        let pageMargins = UIEdgeInsets(top: 32, left: 32, bottom: 32, right: 32)

        // Calculate the printable rect from the above two
        let printableRect = CGRect(x: pageMargins.left, y: pageMargins.top, width: pageSize.width - pageMargins.left - pageMargins.right, height: pageSize.height - pageMargins.top - pageMargins.bottom)
        let paperRect = CGRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)

        renderer.setValue(NSValue(cgRect: paperRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: printableRect), forKey: "printableRect")

        let data = NSMutableData()

        UIGraphicsBeginPDFContextToData(data, paperRect, nil)
        renderer.prepare(forDrawingPages: NSMakeRange(0, renderer.numberOfPages))

        let bounds = UIGraphicsGetPDFContextBounds()
        for i in 0  ..< renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: bounds)
        }
        UIGraphicsEndPDFContext()

        return data as Data
    }
#endif
}

#warning("TODO: remove unused values")
final class TextHelpers {
    let fontHeadline: UXFont
    let fontBody: UXFont
    let fontMono: UXFont
    let fontCaption: UXFont

    let captionAttributes: [NSAttributedString.Key: Any]
    let spacerAttributes: [NSAttributedString.Key: Any]

    let monoParagraphStyle: NSParagraphStyle

    let bodParagraphStyle: NSParagraphStyle
    private(set) var textAttributes: [LoggerStore.Level: [NSAttributedString.Key: Any]] = [:]
    var detailsAttributes: [NSAttributedString.Key: Any] { textAttributes[.debug]! }

    init(options: TextRenderer.Options) {
#warning("TODO: remove these fonts?")
        self.fontHeadline = .preferredFont(forTextStyle: .headline)
        self.fontBody = .preferredFont(forTextStyle: .body)
        self.fontCaption = .preferredFont(forTextStyle: .caption1)
        self.fontMono = .monospacedSystemFont(ofSize: TextSize.mono, weight: .regular)

        let lineHeight = geLineHeight(for: Int(options.fontSize))
        self.bodParagraphStyle = NSParagraphStyle.make(lineHeight: lineHeight)

        self.monoParagraphStyle = NSParagraphStyle.make(lineHeight: TextSize.mono + 6)

        self.captionAttributes = [
            .font: fontCaption,
            .foregroundColor: UXColor.secondaryLabel,
            .paragraphStyle: bodParagraphStyle
        ]

        self.spacerAttributes = [
            .font: fontCaption,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.maximumLineHeight = 10
                style.minimumLineHeight = 10
                return style
            }()
        ]

        func makeLabelAttributes(level: LoggerStore.Level) -> [NSAttributedString.Key: Any] {
            let textColor: UXColor
            if #available(iOS 14, tvOS 14, *), !options.isMonocrhome {
                textColor = level == .trace ? .secondaryLabel : UXColor(ConsoleMessageStyle.textColor(level: level))
            } else {
                textColor = .label
            }
            return [
                .font: fontCaption,
                .foregroundColor: textColor,
                .paragraphStyle: bodParagraphStyle
            ]
        }

        for level in LoggerStore.Level.allCases {
            textAttributes[level] = makeLabelAttributes(level: level)
        }
    }

    #warning("TODO: move body and KeyValueSectoinView rendering here too")
}

struct TextSize {
    static let headline = fontSize(for: .headline)
    static let body = fontSize(for: .body)
    static let mono = fontSize(for: .body) - 5
    static let callout = fontSize(for: .callout)
    static let caption = fontSize(for: .caption1)
}

private func fontSize(for style: UXFont.TextStyle) -> CGFloat {
    UXFont.preferredFont(forTextStyle: style).fontDescriptor.pointSize
}

#warning("TODO: remove")
private func geLineHeight(for fontSize: Int) -> CGFloat {
    CGFloat(fontSize + 6)
}

struct RenteredNetworkContent: OptionSet {
    let rawValue: Int16

    init(rawValue: Int16) {
        self.rawValue = rawValue
    }

    static let requestComponents = RenteredNetworkContent(rawValue: 1 << 0)
    static let requestQueryItems = RenteredNetworkContent(rawValue: 1 << 1)
    static let errorDetails = RenteredNetworkContent(rawValue: 1 << 2)
    static let originalRequestHeaders = RenteredNetworkContent(rawValue: 1 << 3)
    static let currentRequestHeaders = RenteredNetworkContent(rawValue: 1 << 5)
    static let requestOptions = RenteredNetworkContent(rawValue: 1 << 7)
    static let requestBody = RenteredNetworkContent(rawValue: 1 << 8)
    static let responseHeaders = RenteredNetworkContent(rawValue: 1 << 9)
    static let responseBody = RenteredNetworkContent(rawValue: 1 << 11)

    #warning("TODO: add subset for sharing (not all?)")

    static let all: RenteredNetworkContent = [
        requestComponents,
        requestQueryItems,
        errorDetails,
        originalRequestHeaders,
        currentRequestHeaders,
        requestOptions,
        requestBody,
        responseHeaders,
        responseBody
    ]
}

#warning("TODO: remove")
@available(*, deprecated, message: "Deprecated")
enum FontSize {
    static var body: CGFloat {
        #if os(iOS)
            return 13
        #elseif os(macOS)
            return 12
        #elseif os(tvOS)
            return 24
        #else
            return 12
        #endif
    }
}

// MARK: - Previews

#warning("TODO: enable previews on other platforms")

#if DEBUG
struct ConsoleTextRenderer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let string = TextRenderer(options: .init(networkContent: [.all])).render(task)
            let string2 = TextRenderer(options: .init(networkContent: [.all], isMonocrhome: false)).render(task)
            let html = try! TextRenderer.html(from: string)
            let pdf = try! TextRenderer.pdf(from: string)

            RichTextView(viewModel: .init(string: string))
                .previewDisplayName("NSAttributedString")

            RichTextView(viewModel: .init(string: string2))
                .previewDisplayName("NSAttributedString (Color)")

            RichTextView(viewModel: .init(string: string.string))
                .previewDisplayName("Plain Text")

            RichTextView(viewModel: .init(string: HTMLPrettyPrint(string: String(data: html, encoding: .utf8)!).render()))
                .previewLayout(.fixed(width: 1160, height: 2000)) // Disable interaction to view it
                .previewDisplayName("HTML (Raw)")

#if os(iOS) || os(macOS)
            WebView(data: html, contentType: "application/html")
                .previewDisplayName("HTML")
#endif

#if !os(watchOS)
            PDFKitRepresentedView(document: PDFDocument(data: pdf)!)
                .previewDisplayName("PDF")
#endif
        }
    }
}

private let task = LoggerStore.preview.entity(for: .login)
#endif

#warning("TODO: remove this when we are done with HTML output")

private let style = """
<style>
  body {
    font: 400 16px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text","SF Pro Icons","Helvetica Neue",Helvetica,Arial,sans-serif;
    background-color: #FDFDFD;
    color: #353535;
  }
  pre {
    font-family: 'SF Mono', Menlo, monospace, Courier, Consolas, "Liberation Mono", monospace;
    font-size: 14px;
    overflow-x: auto;
  }
  h2 {
    margin-top: 30px;
    padding-bottom: 8px;
    border-bottom: 2px solid #DDDDDD;
    font-weight: 600;
    font-size: 34px;
  }
  ul {
    list-style: none;
    padding-left: 0;
  }
  li {
    overflow-wrap: break-word;
  }
  strong {
    font-weight: 600;
    color: #737373;
  }
  main {
    max-width: 900px;
    padding: 15px;
  }
  pre {
    padding: 8px;
    border-radius: 8px;
    background-color: #FDFDFD;
  }
  a {
    color: #0066FF;
  }
  .s { color: rgb(255, 45, 85); }
  .o { color: rgb(0, 122, 255); }
  .n { color: rgb(191, 90, 242); }
  .err { background-color: red; }
  @media (prefers-color-scheme: dark) {
    body {
      background-color: #211F1E;
      color: #DFDFDF;
    }
    strong {
      color: #878787;
    }
    h2 {
      border-bottom: 2px solid #3C3A38;
    }
    pre {
      background-color: #2C2A28;
    }
    a {
      color: #67A6F8;
    }
    .s { color: rgb(255, 55, 95); }
    .o { color: rgb(10, 132, 255); }
    .n { color: rgb(175, 82, 222); }
  }
}
</style>
"""
