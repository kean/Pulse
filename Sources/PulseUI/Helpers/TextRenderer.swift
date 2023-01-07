// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#warning("TODO: add PDF export and test printing")

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

#if os(iOS)
import PDFKit
#endif

/// Low-level attributed string creation API.
final class TextRenderer {
    struct Options {
        var color: ColorMode = .full
    }

    enum ColorMode: String, RawRepresentable {
        case monochrome
        case automatic
        case full
    }

    private let options: Options

    let helper: TextHelper

    init(options: Options = .init()) {
        self.options = options
        self.helper = TextHelper()
    }

    func joined(_ strings: [NSAttributedString]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for (index, string) in strings.enumerated() {
            output.append(string)
            if index < strings.endIndex - 1 {
                output.append(spacer())
            }
        }
        return output
    }

    func spacer() -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: helper.spacerAttributes)
    }

    func render(_ message: LoggerMessageEntity) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let viewModel = ConsoleMessageViewModel(message: message)
        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        text.append(viewModel.titleForTextRepresentation + "\n", helper.attributes(role: .subheadline, style: .monospacedDigital, width: .condensed, color: .secondaryLabel))
        text.append(message.text + "\n", helper.attributes(role: .body2, color: textColor(for: level)))
        return text
    }

    private func textColor(for level: LoggerStore.Level) -> UXColor {
        if #available(iOS 14, tvOS 14, *), options.color != .monochrome {
            return level == .trace ? .secondaryLabel : UXColor(ConsoleMessageStyle.textColor(level: level))
        } else {
            return .label
        }
    }

    func render(_ task: NetworkTaskEntity, content: NetworkContent) -> NSAttributedString {
        var components: [NSAttributedString] = []

        if content.contains(.header) {
            let isTitleColored = task.state == .failure && options.color != .monochrome
            let titleColor = isTitleColored ? UXColor.systemRed : UXColor.secondaryLabel
            let detailsColor = isTitleColored ? UXColor.systemRed : UXColor.label

            let title = ConsoleFormatter.subheadline(for: task)
            let header = NSMutableAttributedString()
            header.append(title + "\n", helper.attributes(role: .subheadline, style: .monospacedDigital, width: .condensed, color: titleColor))
            header.append((task.url ?? "–") + "\n", helper.attributes(role: .body2, weight: .medium, color: detailsColor))
            components.append(header)
        }

        func append(section: KeyValueSectionViewModel?) {
            guard let section = section else { return }
            components.append(render(section))
        }

        if content.contains(.requestComponents), let url = task.url.flatMap(URL.init) {
            append(section: .makeComponents(for: url))
        }
        if content.contains(.requestQueryItems), let url = task.url.flatMap(URL.init) {
            append(section: .makeQueryItems(for: url))
        }
        if content.contains(.requestOptions), let request = task.originalRequest {
            append(section: .makeParameters(for: request))
        }
        if content.contains(.errorDetails) {
            append(section: .makeErrorDetails(for: task))
        }
        if let originalRequest = task.originalRequest {
            if content.contains(.originalRequestHeaders) && content.contains(.currentRequestHeaders), let currentRequest = task.currentRequest {
                append(section: .makeHeaders(title: "Original Request Headers", headers: originalRequest.headers))
                append(section: .makeHeaders(title: "Current Request Headers", headers: currentRequest.headers))
            } else if content.contains(.originalRequestHeaders) {
                append(section: .makeHeaders(title: "Request Headers", headers: originalRequest.headers))
            } else if content.contains(.currentRequestHeaders), let currentRequest = task.currentRequest {
                append(section: .makeHeaders(title: "Request Headers", headers: currentRequest.headers))
            }
            if content.contains(.requestBody) {
                let section = NSMutableAttributedString()
                section.append(render(subheadline: "Request Body"))
                section.append(renderRequestBody(for: task))
                section.append("\n")
                components.append(section)
            }
        }
        if content.contains(.responseHeaders), let response = task.response {
            append(section: .makeHeaders(title: "Response Headers", headers: response.headers))
        }
        if content.contains(.responseBody) {
            let section = NSMutableAttributedString()
            section.append(render(subheadline: "Response Body"))
            section.append(renderResponseBody(for: task))
            section.append("\n")
            components.append(section)
        }
        return joined(components)
    }

    func render(subheadline: String) -> NSAttributedString {
        render(subheadline + "\n", role: .subheadline, color: .secondaryLabel)
    }

    func renderRequestBody(for task: NetworkTaskEntity) -> NSAttributedString {
        if let data = task.requestBody?.data, !data.isEmpty {
            return renderNetworkTaskBody(data, contentType: task.response?.contentType, error: nil)
        } else if task.state == .success, task.type == .uploadTask, task.requestBodySize > 0 {
            return render("\(ByteCountFormatter.string(fromByteCount: task.requestBodySize))", role: .body2)
        } else {
            return render("–", role: .body2)
        }
    }

    func renderResponseBody(for task: NetworkTaskEntity) -> NSAttributedString {
        if let data = task.responseBody?.data, !data.isEmpty {
            return renderNetworkTaskBody(data, contentType: task.response?.contentType, error: task.decodingError)
        } else if task.type == .downloadTask, task.responseBodySize > 0 {
            return render("\(ByteCountFormatter.string(fromByteCount: task.responseBodySize))", role: .body2)
        } else {
            return render("–", role: .body2)
        }
    }

    func render(json: Any, error: NetworkLogger.DecodingError? = nil) -> NSAttributedString {
        TextRendererJSON(json: json, error: error, options: options).render()
    }

#warning("TODO: reuse this somehow with FileViewerViewModel")
    private func renderNetworkTaskBody(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?) -> NSAttributedString {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            return render(json: json, error: error)
        } else if let string = String(data: data, encoding: .utf8) {
            if contentType?.isEncodedForm ?? false, let section = decodeQueryParameters(form: string) {
                return render(section, style: .monospaced)
            } else if contentType?.isHTML ?? false {
                return TextRendererHTML(html: string, options: options).render()
            }
            return render(string, role: .body2, style: .monospaced)
        } else {
            return render("\(ByteCountFormatter.string(fromByteCount: Int64(data.count)))", role: .body2)
        }
    }

    private func decodeQueryParameters(form string: String) -> KeyValueSectionViewModel? {
        let string = "https://placeholder.com/path?" + string
        guard let components = URLComponents(string: string),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return nil
        }
        return KeyValueSectionViewModel.makeQueryItems(for: queryItems)
    }

    func render(_ section: KeyValueSectionViewModel, style: TextFontStyle = .monospaced) -> NSAttributedString {
        let string = NSMutableAttributedString()
        string.append(render(subheadline: section.title))
        string.append(render(section.items, color: section.color, style: style))
        return string
    }

    func render(_ values: [(String, String?)]?, color: Color, style: TextFontStyle = .monospaced) -> NSAttributedString {
        let string = NSMutableAttributedString()
        guard let values = values, !values.isEmpty else {
            string.append("–\n", helper.attributes(role: .body2, style: style))
            return string
        }
        var keyColor: UXColor = .label
        var keyWeight: UXFont.Weight = .semibold
        if #available(iOS 14, tvOS 14, *), options.color == .full {
            keyColor = UXColor(color)
            keyWeight = .medium
        }
        let keyAttributes = helper.attributes(role: .body2, style: style, weight: keyWeight, color: keyColor)

        let valueAttributes = helper.attributes(role: .body2, style: style)
        let separatorAttributes = helper.attributes(role: .body2, style: style, color: .secondaryLabel)
        for (key, value) in values {
            string.append(key, keyAttributes)
            string.append(": ", separatorAttributes)
            string.append("\(value ?? "–")\n", valueAttributes)
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

    func preformatted(_ string: String, color: UXColor? = nil) -> NSAttributedString {
        render(string, role: .body2, style: .monospaced, color: color ?? .label)
    }

    func render(
        _ string: String,
        role: TextRole,
        style: TextFontStyle = .proportional,
        weight: UXFont.Weight = .regular,
        width: TextWidth = .standard,
        color: UXColor = .label
    ) -> NSAttributedString {
        let attributes = helper.attributes(role: role, style: style, weight: weight, width: width, color: color)
        return NSAttributedString(string: string, attributes: attributes)
    }
}


extension NSAttributedString.Key {
    static let objectIdKey = NSAttributedString.Key("pulse-object-id-key")
    static let isTechnicalKey = NSAttributedString.Key("pulse-technical-substring-key")
}

// MARK: - Previews

#warning("TODO: add other preview using this")

#if DEBUG
struct ConsoleTextRenderer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let string = TextRenderer(options: .init(color: .automatic)).render(task, content: .all)
            let stringWithColor = TextRenderer(options: .init(color: .full)).render(task, content: .all)
            let html = try! TextRenderer.html(from: string)

            RichTextView(viewModel: .init(string: string))
                .previewDisplayName("Task")

            RichTextView(viewModel: .init(string: stringWithColor))
                .previewDisplayName("Task (Color)")

            RichTextView(viewModel: .init(string: string.string))
                .previewDisplayName("Task (Plain)")

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
