// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#warning("TODO: add PDF export and test printing")
#warning("TODO: add metrics and cookies and other missing values from summary")
#warning("TODO: remove FontSize setting from ConsoleTextView for now")
#warning("TODO: do other styles work?")

#if !os(watchOS)

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse
import PDFKit

/// Renders console messages as attributed strings.
final class TextRenderer {
    struct Options {
        var networkContent: RenteredNetworkContent = [.errorDetails, .requestBody, .responseBody]
        var isMonocrhome = true
        var isBodySyntaxHighlightingEnabled = true
        var isBodyExpanded = false
        var bodyCollapseLimit = 20
        var fontSize: CGFloat = 15
        var isHTMLSafeFonts = false
    }

    private var options: Options = .init()
    private var helpers = TextHelpers(options: .init())
    private var index = 0

    #warning("TODO: remove options parameter & move expanded to Console (or options?)")
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

    func render(_ entities: [NetworkTaskEntity], options: Options = .init()) -> NSAttributedString {
        prepare(options: options)
        return joined(entities.map(render))
    }

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

        if let url = task.url {
            var attributes = helpers.textAttributes[.debug]!
            attributes[.font] = UXFont.systemFont(ofSize: options.fontSize, weight: .medium)
            if !options.isMonocrhome {
                attributes[.foregroundColor] = tintColor
            }
            text.append(url + "\n", attributes)
        }

        let viewModel = NetworkInspectorSummaryViewModel(task: task)
        let content = options.networkContent

        if content.contains(.errorDetails) {
            append(section: viewModel.errorModel)
        }

        if task.originalRequest != nil {
            let originalHeaders = viewModel.originalRequestHeaders
            var currentHeaders = viewModel.currentRequestHeaders
            if content.contains(.originalRequestHeaders) {
                append(section:originalHeaders .title("Original Request Headers"))
            }
            if content.contains(.currentRequestHeaders), task.currentRequest != nil {
                if task.originalRequest?.headers == task.currentRequest?.headers {
                    currentHeaders.items = [("Headers", "<original>")]
                }
                append(section: currentHeaders.title("Current Request Headers"))
            }
            if content.contains(.requestOptions) {
                append(section: viewModel.originalRequestParameters?.title("Request Options"))
            }
            if content.contains(.requestBody), let data = task.requestBody?.data, !data.isEmpty {
                text.append("\n", helpers.spacerAttributes)
                text.append("Request Body\n", helpers.captionAttributes)
                text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
                text.append("\n", helpers.detailsAttributes)
            }
        }
        if content.contains(.responseHeaders), task.response != nil {
            append(section: viewModel.responseHeaders.title("Response Headers"))
        }
        if content.contains(.responseBody), let data = task.responseBody?.data, !data.isEmpty {
            text.append("\n", helpers.spacerAttributes)
            text.append("Response Body\n", helpers.captionAttributes)
            text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
            text.append("\n", helpers.detailsAttributes)
        }
        return text
    }

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

    private func decodeQueryParameters(form string: String) -> KeyValueSectionViewModel? {
        let string = "https://placeholder.com/path?" + string
        guard let components = URLComponents(string: string),
              let queryItems = components.queryItems,
              !queryItems.isEmpty else {
            return nil
        }
        return KeyValueSectionViewModel.makeQueryItems(for: queryItems, action: {})
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

    /// Renderes the given attributed string as PDF
#if canImport(UIKit)
    static func pdf(from string: NSAttributedString) throws -> Data {
        let formatter = UISimpleTextPrintFormatter(attributedText: string)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

        let pageSize = CGSize(width: 612, height: 792) // US letter size
        let pageMargins = UIEdgeInsets(top: 64, left: 64, bottom: 64, right: 64)

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

    let paragraphStyle: NSParagraphStyle
    private(set) var textAttributes: [LoggerStore.Level: [NSAttributedString.Key: Any]] = [:]
    var detailsAttributes: [NSAttributedString.Key: Any] { textAttributes[.debug]! }

    init(options: TextRenderer.Options) {
#warning("TODO: remove these fonts?")
        self.fontHeadline = .preferredFont(forTextStyle: .headline)
        self.fontBody = .preferredFont(forTextStyle: .body)
        self.fontCaption = .preferredFont(forTextStyle: .caption1)
        self.fontMono = .monospacedSystemFont(ofSize: TextSize.mono, weight: .regular)

        let lineHeight = geLineHeight(for: Int(options.fontSize))
        self.paragraphStyle = NSParagraphStyle.make(lineHeight: lineHeight)

        self.monoParagraphStyle = NSParagraphStyle.make(lineHeight: TextSize.mono + 6)

        self.captionAttributes = [
            .font: fontCaption,
            .foregroundColor: UXColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
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
                .paragraphStyle: paragraphStyle
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

    static let errorDetails = RenteredNetworkContent(rawValue: 1 << 0)
    static let originalRequestHeaders = RenteredNetworkContent(rawValue: 1 << 2)
    static let currentRequestHeaders = RenteredNetworkContent(rawValue: 1 << 3)
    static let requestOptions = RenteredNetworkContent(rawValue: 1 << 4)
    static let requestBody = RenteredNetworkContent(rawValue: 1 << 5)
    static let responseHeaders = RenteredNetworkContent(rawValue: 1 << 6)
    static let responseBody = RenteredNetworkContent(rawValue: 1 << 7)

    static let all: RenteredNetworkContent = [
        errorDetails, originalRequestHeaders, currentRequestHeaders, requestOptions, requestBody, responseHeaders, responseBody
    ]
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

#if DEBUG
struct ConsoleTextRenderer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let renderer = TextRenderer()
            let string = renderer.render([task], options: .init(networkContent: [.all]))
            let safeString = renderer.render([task], options: .init(networkContent: [.all], isHTMLSafeFonts: true))
            let html = try! TextRenderer.html(from: safeString)
            let pdf = try! TextRenderer.pdf(from: safeString)

            RichTextView(viewModel: .init(string: string))
                .previewDisplayName("NSAttributedString")

            RichTextView(viewModel: .init(string: string.string))
                .previewDisplayName("Plain Text")

            RichTextView(viewModel: .init(string: HTMLPrettyPrint(string: String(data: html, encoding: .utf8)!).render()))
                .previewLayout(.fixed(width: 1160, height: 2000)) // Disable interaction to view it
                .previewDisplayName("HTML (Raw)")

            WebView(data: html, contentType: "application/html")
                .previewDisplayName("HTML")

            PDFKitRepresentedView(document: PDFDocument(data: pdf)!)
                .previewDisplayName("PDF")
        }
    }
}

private let task = LoggerStore.preview.entity(for: .login)
#endif

#endif
