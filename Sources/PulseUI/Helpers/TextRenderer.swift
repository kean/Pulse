// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#warning("TODO: add PDF export and test printing")
#warning("TODO: add metrics and cookies and other missing values from summary")
#warning("TODO: do other styles work?")

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

#if os(iOS)
import PDFKit
#endif

/// Renders console messages as attributed strings.
final class TextRenderer {
    struct Options {
        var networkContent: NetworkContent = [.errorDetails, .requestBody, .responseBody]
        var color: ColorMode = .full

#warning("TODO: rework body collapse")
        var isBodyExpanded = false
        var bodyCollapseLimit = 20
    }

    struct NetworkContent: OptionSet {
        let rawValue: Int16
        init(rawValue: Int16) { self.rawValue = rawValue }

        static let requestComponents = NetworkContent(rawValue: 1 << 0)
        static let requestQueryItems = NetworkContent(rawValue: 1 << 1)
        static let errorDetails = NetworkContent(rawValue: 1 << 2)
        static let originalRequestHeaders = NetworkContent(rawValue: 1 << 3)
        static let currentRequestHeaders = NetworkContent(rawValue: 1 << 5)
        static let requestOptions = NetworkContent(rawValue: 1 << 7)
        static let requestBody = NetworkContent(rawValue: 1 << 8)
        static let responseHeaders = NetworkContent(rawValue: 1 << 9)
        static let responseBody = NetworkContent(rawValue: 1 << 11)

        #warning("TODO: add subset for sharing (not all?)")

        static let all: NetworkContent = [
            requestComponents, requestQueryItems, errorDetails, originalRequestHeaders, currentRequestHeaders, requestOptions, requestBody, responseHeaders, responseBody
        ]
    }

    enum ColorMode: String, RawRepresentable {
        case monochrome
        case automatic
        case full
    }

    private let options: Options
    private let helpers: TextHelper

    init(options: Options = .init()) {
        self.options = options
        self.helpers = TextHelper(options: options)
    }

    func joined(_ strings: [NSAttributedString]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for string in strings {
            output.append(string)
            output.append("\n", helpers.spacerAttributes)
        }
        return output
    }

    func render(_ message: LoggerMessageEntity) -> NSAttributedString {
        render(message, index: nil, isExpanded: true)
    }

    func render(_ message: LoggerMessageEntity, index: Int?, isExpanded: Bool) -> NSAttributedString {
        if let task = message.task {
            return render(task, index: index, isExpanded: isExpanded)
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
        render(task, index: nil, isExpanded: true)
    }

    func render(_ task: NetworkTaskEntity, index: Int?, isExpanded: Bool) -> NSAttributedString {
#warning("TODO: refactor remainig")
#warning("TODO: fix fonts on other platforms, e.g. URL on tvOS")

        let string = NSMutableAttributedString()

        let topViewModel = ConsoleNetworkRequestViewModel(task: task)
        let title = topViewModel.titleForTextRepresentation

        string.append(title + "\n", {
            var attributes = helpers.captionAttributes
            if task.state == .failure && options.color != .monochrome {
                attributes[.foregroundColor] = UXColor.systemRed
            }
            return attributes
        }())

        func append(section: KeyValueSectionViewModel?) {
            guard let section = section else { return }
            string.append("\n", helpers.spacerAttributes)
            string.append(render(section))
        }

        let url = task.url.flatMap(URL.init) ?? URL(string: "invalid-url")!

        string.append(url.absoluteString + "\n", {
            var attributes = helpers.textAttributes[.debug]!
            attributes[.font] = UXFont.systemFont(ofSize: TextSize.body, weight: .medium)
            if task.state == .failure && options.color != .monochrome {
                attributes[.foregroundColor] = UXColor.systemRed
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
                    string.append("Same as Original", [
                        .font: UXFont.systemFont(ofSize: TextSize.body, weight: .regular),
                        .foregroundColor: UXColor.secondaryLabel,
                        .paragraphStyle: helpers.bodyParagraphStyle
                    ])
                } else {
                    append(section: .makeHeaders(title: "Current Request Headers", headers: currentRequest.headers))
                }
            }
            if content.contains(.requestBody), let data = task.requestBody?.data, !data.isEmpty {
                string.append("\n", helpers.spacerAttributes)
                string.append("Request Body\n", helpers.captionAttributes)
                string.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError, index: index, isExpanded: isExpanded))
                string.append("\n", helpers.detailsAttributes)
            }
        }
        if content.contains(.responseHeaders), let response = task.response {
            append(section: .makeHeaders(title: "Response Headers", headers: response.headers))
        }
        if content.contains(.responseBody), let data = task.responseBody?.data, !data.isEmpty {
            string.append("\n", helpers.spacerAttributes)
            string.append("Response Body\n", helpers.captionAttributes)
            string.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError, index: index, isExpanded: isExpanded))
            string.append("\n", helpers.detailsAttributes)
        }
        return string
    }

#warning("TODO: rework this")
    private func renderNetworkTaskBody(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?, index: Int?, isExpanded: Bool) -> NSAttributedString {
        let text = NSMutableAttributedString(attributedString: _renderNetworkTaskBody(data, contentType: contentType, error: error))
        if !options.isBodyExpanded && !isExpanded, let index = index {
            let string = text.string as NSString
            var counter = 0
            var stringIndex = 0
            while stringIndex < string.length, counter < options.bodyCollapseLimit {
                if string.character(at: stringIndex) == 0x0a {
                    counter += 1
                }
                stringIndex += 1
            }
            if stringIndex != string.length {
                do { // trim newlines
                    while stringIndex > 1, string.character(at: stringIndex - 1) == 0x0a {
                        stringIndex -= 1
                    }
                }
                let text = NSMutableAttributedString(attributedString: text.attributedSubstring(from: NSRange(location: 0, length: stringIndex)))
                var attributes = helpers.detailsAttributes
                attributes[.foregroundColor] = UXColor.systemBlue
                attributes[.link] = URL(string: "pulse://expand/\(index)")
                attributes[.underlineColor] = UXColor.clear
                text.append("\n", helpers.spacerAttributes)
                text.append("\nExpand ▷", attributes)
                return text
            }
        }
        return text
    }

    private func _renderNetworkTaskBody(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?) -> NSAttributedString {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            let renderer = TextRendererJSON(json: json, error: error, options: options)
            return renderer.render()
        } else if let string = String(data: data, encoding: .utf8) {
            if contentType?.isEncodedForm ?? false, let components = decodeQueryParameters(form: string) {
                return components.asAttributedString()
            } else if contentType?.isHTML ?? false {
                return TextRendererHTML(html: string, options: options).render()
            }
            return NSAttributedString(string: string, attributes: helpers.textAttributes[.debug]!)
        } else {
            let message = "Data \(ByteCountFormatter.string(fromByteCount: Int64(data.count)))"
            return NSAttributedString(string: message, attributes: helpers.textAttributes[.debug]!)
        }
    }

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

    func render(_ section: KeyValueSectionViewModel, style: TextStyle = .monospaced) -> NSAttributedString {
        let string = NSMutableAttributedString()
        string.append(section.title + "\n", helpers.captionAttributes)
        string.append(render(section.items, color: section.color, style: style))
        return string
    }

#warning("TODO: add support for other styles")
    func render(_ values: [(String, String?)]?, color: Color, style: TextStyle = .monospaced) -> NSAttributedString {
        let string = NSMutableAttributedString()
        guard let values = values, !values.isEmpty else {
            return string
        }
        var keyAttributes = helpers.attributes(for: style, weight: .semibold)
        if #available(iOS 14, tvOS 14, *), options.color == .full {
            keyAttributes[.foregroundColor] = UXColor(color)
        }
        let valueAttributes = helpers.attributes(for: style)
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
#if os(iOS)
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

    func render(_ string: String, style: TextStyle, weight: UXFont.Weight = .regular) -> NSAttributedString {
        NSAttributedString(string: string, attributes: helpers.attributes(for: style, weight: weight))
    }
}

#warning("TODO: remove unused values")
final class TextHelper {
    let fontHeadline: UXFont
    let fontBody: UXFont
    let fontMono: UXFont
    let fontCaption: UXFont

    let captionAttributes: [NSAttributedString.Key: Any]
    let spacerAttributes: [NSAttributedString.Key: Any]
    let monospacedAttributes: [NSAttributedString.Key: Any]
    let bodyAttributes: [NSAttributedString.Key: Any]

    let monoParagraphStyle: NSParagraphStyle

    let bodyParagraphStyle: NSParagraphStyle
    private(set) var textAttributes: [LoggerStore.Level: [NSAttributedString.Key: Any]] = [:]
    var detailsAttributes: [NSAttributedString.Key: Any] { textAttributes[.debug]! }

    init(options: TextRenderer.Options) {
#warning("TODO: remove these fonts?")
        self.fontHeadline = .preferredFont(forTextStyle: .headline)
        self.fontBody = .systemFont(ofSize: TextSize.body, weight: .regular)
        self.fontCaption = .preferredFont(forTextStyle: .caption1)
        self.fontMono = .monospacedSystemFont(ofSize: TextSize.mono, weight: .regular)

        self.bodyParagraphStyle = NSParagraphStyle.make(lineHeight: TextSize.body + 6)
        self.bodyAttributes = [
            .font: fontBody,
            .foregroundColor: UXColor.label,
            .paragraphStyle: bodyParagraphStyle
        ]

        self.monoParagraphStyle = NSParagraphStyle.make(lineHeight: TextSize.mono + 6)
        self.monospacedAttributes = [
            .font: fontMono,
            .paragraphStyle: monoParagraphStyle,
            .foregroundColor: UXColor.label
        ]
        self.captionAttributes = [
            .font: fontCaption,
            .foregroundColor: UXColor.secondaryLabel,
            .paragraphStyle: bodyParagraphStyle
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
            if #available(iOS 14, tvOS 14, *), options.color != .monochrome {
                textColor = level == .trace ? .secondaryLabel : UXColor(ConsoleMessageStyle.textColor(level: level))
            } else {
                textColor = .label
            }
            return [
                .font: UXFont.systemFont(ofSize: TextSize.body),
                .foregroundColor: textColor,
                .paragraphStyle: bodyParagraphStyle
            ]
        }

        for level in LoggerStore.Level.allCases {
            textAttributes[level] = makeLabelAttributes(level: level)
        }
    }

    func attributes(for style: TextStyle, weight: UXFont.Weight = .regular) -> [NSAttributedString.Key: Any] {
        switch style {
        case .body:
            var attributes = bodyAttributes
            if weight != .regular {
                attributes[.font] = UXFont.systemFont(ofSize: TextSize.body, weight: weight)
            }
            return attributes
        case .monospaced:
            var attributes = monospacedAttributes
            if weight != .regular {
                attributes[.font] = UXFont.monospacedSystemFont(ofSize: TextSize.mono, weight: weight)
            }
            return attributes
        }
    }

    #warning("TODO: move body and KeyValueSectoinView rendering here too")
}

enum TextStyle {
    case body
    case monospaced
}

struct TextSize {
    static let headline = fontSize(for: .headline)
    static let body = fontSize(for: .body) - 2
    static let mono = fontSize(for: .body) - 4
    static let caption = fontSize(for: .caption1)
}

private func fontSize(for style: UXFont.TextStyle) -> CGFloat {
    UXFont.preferredFont(forTextStyle: style).fontDescriptor.pointSize
}

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
            let stringWithColor = TextRenderer(options: .init(networkContent: [.all], color: .full)).render(task)
            let html = try! TextRenderer.html(from: string)

            RichTextView(viewModel: .init(string: string))
                .previewDisplayName("NSAttributedString")

            RichTextView(viewModel: .init(string: stringWithColor))
                .previewDisplayName("NSAttributedString (Color)")

            RichTextView(viewModel: .init(string: string.string))
                .previewDisplayName("Plain Text")

            RichTextView(viewModel: .init(string: TextRendererHTML(html: String(data: html, encoding: .utf8)!).render()))
                .previewLayout(.fixed(width: 1160, height: 2000)) // Disable interaction to view it
                .previewDisplayName("HTML (Raw)")

#if os(iOS) || os(macOS)
            WebView(data: html, contentType: "application/html")
                .previewDisplayName("HTML")
#endif

#if os(iOS)
            PDFKitRepresentedView(document: PDFDocument(data: try! TextRenderer.pdf(from: string))!)
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
