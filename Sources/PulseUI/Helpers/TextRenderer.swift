// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

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

        static let sharing = Options(color: .automatic)
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
        text.append(viewModel.titleForTextRepresentation + "\n", helper.attributes(role: .subheadline, style: .monospacedDigital, width: .condensed, color: .secondaryLabel))
        text.append(message.text + "\n", helper.attributes(role: .body2, color: textColor(for: message.logLevel)))
        return text
    }

    private func textColor(for level: LoggerStore.Level) -> UXColor {
        if #available(iOS 14, tvOS 14, *), options.color != .monochrome {
            return level == .trace ? .secondaryLabel : UXColor(ConsoleMessageStyle.textColor(for: level))
        } else {
            return .label
        }
    }

    func render(_ task: NetworkTaskEntity, content: NetworkContent) -> NSAttributedString {
        var components: [NSAttributedString] = []

        let isTitleColored = task.state == .failure && options.color != .monochrome
        let titleColor = isTitleColored ? UXColor.systemRed : UXColor.secondaryLabel
        let detailsColor = isTitleColored ? UXColor.systemRed : UXColor.label

        if content.contains(.largeHeader) {
            let header = NSMutableAttributedString()
            let status = NetworkRequestStatusCellModel(task: task)
            let method = task.httpMethod ?? "GET"
            header.append(render(status.title + "\n", role: .title, weight: .semibold, color: status.uiTintColor))
            header.append(self.spacer())
            var urlAttributes = helper.attributes(role: .body2, weight: .regular)
            urlAttributes[.underlineColor] = UXColor.clear
            header.append(method + "\n", helper.attributes(role: .body, weight: .semibold))
            header.append((task.url ?? "–") + "\n", urlAttributes)
            components.append(header)
        }

        if content.contains(.taskDetails) {
            append(section: .makeTaskDetails(for: task))
        }

        if content.contains(.header) {
            let title = ConsoleFormatter.subheadline(for: task)
            let header = NSMutableAttributedString()
            header.append(title + "\n", helper.attributes(role: .subheadline, style: .monospacedDigital, width: .condensed, color: titleColor))
            var urlAttributes = helper.attributes(role: .body2, weight: .medium, color: detailsColor)
            urlAttributes[.underlineColor] = UXColor.clear
            header.append((task.url ?? "–") + "\n", urlAttributes)
            components.append(header)
        }

        func append(section: KeyValueSectionViewModel?, count: Bool) {
            let isCountDisplayed = count && section?.items.isEmpty == false
            let details = isCountDisplayed ? section?.items.count.description : nil
            append(section: section, details: details)
        }

        func append(section: KeyValueSectionViewModel?, details: String? = nil) {
            guard let section = section else { return }
            components.append(render(section, details: details))
        }
        if content.contains(.errorDetails) {
            append(section: .makeErrorDetails(for: task))
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
        if let originalRequest = task.originalRequest {
            if content.contains(.originalRequestHeaders) && content.contains(.currentRequestHeaders), let currentRequest = task.currentRequest {
                append(section: .makeHeaders(title: "Original Request Headers", headers: originalRequest.headers), count: true)
                append(section: .makeHeaders(title: "Current Request Headers", headers: currentRequest.headers), count: true)
            } else if content.contains(.originalRequestHeaders) {
                append(section: .makeHeaders(title: "Request Headers", headers: originalRequest.headers), count: true)
            } else if content.contains(.currentRequestHeaders), let currentRequest = task.currentRequest {
                append(section: .makeHeaders(title: "Request Headers", headers: currentRequest.headers), count: true)
            }
            if content.contains(.requestBody) {
                let section = NSMutableAttributedString()
                let details = ByteCountFormatter.string(fromBodySize: task.requestBodySize).map { " (\($0))" } ?? ""
                section.append(render(subheadline: "Request Body" + details))
                section.append(renderRequestBody(for: task))
                section.append("\n")
                components.append(section)
            }
        }
        if content.contains(.responseHeaders), let response = task.response {
            append(section: .makeHeaders(title: "Response Headers", headers: response.headers), count: true)
        }
        if content.contains(.responseBody) {
            let section = NSMutableAttributedString()
            let details = ByteCountFormatter.string(fromBodySize: task.responseBodySize).map { " (\($0))" } ?? ""
            section.append(render(subheadline: "Response Body" + details))
            section.append(renderResponseBody(for: task))
            section.append("\n")
            components.append(section)
        }
        return joined(components)
    }

    func render(_ transaction: NetworkTransactionMetricsEntity) -> NSAttributedString {
        var components: [NSAttributedString] = []

        do {
            let header = NSMutableAttributedString()
            let status = NetworkRequestStatusCellModel(transaction: transaction)
            let method = transaction.request.httpMethod ?? "GET"
            header.append(render(status.title + "\n", role: .title, weight: .semibold, color: status.uiTintColor))
            header.append(self.spacer())
            var urlAttributes = helper.attributes(role: .body2, weight: .regular)
            urlAttributes[.underlineColor] = UXColor.clear
            header.append(method + "\n", helper.attributes(role: .body, weight: .semibold))
            header.append((task.url ?? "–") + "\n", urlAttributes)
            components.append(header)
        }

        func append(section: KeyValueSectionViewModel?, count: Bool) {
            let isCountDisplayed = count && section?.items.isEmpty == false
            let details = isCountDisplayed ? section?.items.count.description : nil
            append(section: section, details: details)
        }
        func append(section: KeyValueSectionViewModel?, details: String? = nil) {
            guard let section = section else { return }
            components.append(render(section, details: details))
        }
        if let url = URL(string: transaction.request.url ?? "–") {
            append(section: .makeComponents(for: url))
        }
        append(section: .makeHeaders(title: "Request Headers", headers: transaction.request.headers), count: true)
        if let response = transaction.response {
            append(section: .makeHeaders(title: "Response Headers", headers: response.headers), count: true)
        }
        return joined(components)
    }

    func render(subheadline: String) -> NSAttributedString {
        render(subheadline + "\n", role: .subheadline, color: .secondaryLabel)
    }

    func renderRequestBody(for task: NetworkTaskEntity) -> NSAttributedString {
        if let data = task.requestBody?.data, !data.isEmpty {
            return render(data, contentType: task.response?.contentType, error: nil)
        } else if task.state == .success, task.type == .uploadTask, task.requestBodySize > 0 {
            return _render(dataSize: task.responseBodySize, contentType: task.originalRequest?.contentType)
        } else {
            return render("–", role: .body2)
        }
    }

    func renderResponseBody(for task: NetworkTaskEntity) -> NSAttributedString {
        if let data = task.responseBody?.data, !data.isEmpty {
            return render(data, contentType: task.response?.contentType, error: task.decodingError)
        } else if task.type == .downloadTask, task.responseBodySize > 0 {
            return _render(dataSize: task.responseBodySize, contentType: task.response?.contentType)
        } else {
            return render("–", role: .body2)
        }
    }

    func render(json: Any, error: NetworkLogger.DecodingError? = nil) -> NSAttributedString {
        TextRendererJSON(json: json, error: error, options: options).render()
    }

    func render(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?) -> NSAttributedString {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            return render(json: json, error: error)
        }
        if let string = String(data: data, encoding: .utf8) {
            if contentType?.isEncodedForm ?? false, let section = decodeQueryParameters(form: string) {
                return render(section, style: .monospaced)
            } else if contentType?.isHTML ?? false {
                return TextRendererHTML(html: string, options: options).render()
            }
            return preformatted(string)
        } else {
            return _render(dataSize: Int64(data.count), contentType: contentType)
        }
    }

    private func _render(dataSize: Int64, contentType: NetworkLogger.ContentType?) -> NSAttributedString {
        let string = [
            ByteCountFormatter.string(fromByteCount: dataSize),
            contentType.map { "(\($0.rawValue))" }
        ].compactMap { $0 }.joined(separator: " ")
        return render(string, role: .body2)
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

    func render(_ section: KeyValueSectionViewModel, details: String? = nil, style: TextFontStyle = .monospaced) -> NSAttributedString {
        let string = NSMutableAttributedString()
        let details = details.map { "(\($0))" }
        let title = [section.title, details].compactMap { $0 }.joined(separator: " ")
        string.append(render(subheadline: title))
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

#if DEBUG
struct ConsoleTextRenderer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            let string = TextRenderer(options: .sharing).render(task, content: .all)
            let stringWithColor = TextRenderer(options: .init(color: .full)).render(task, content: .all)
            let html = try! TextUtilities.html(from: TextRenderer(options: .sharing).render(task, content: .sharing))

            RichTextView(viewModel: .init(string: string))
                .previewDisplayName("Task")

            RichTextView(viewModel: .init(string: TextRenderer(options: .sharing).render(task, content: .sharing)))
                .previewDisplayName("Task (Share)")

            RichTextView(viewModel: .init(string: stringWithColor))
                .previewDisplayName("Task (Color)")

            RichTextView(viewModel: .init(string: string.string))
                .previewDisplayName("Task (Plain)")

            RichTextView(viewModel: .init(string: TextRenderer(options: .sharing).render(task.orderedTransactions[0])))
                .previewDisplayName("Transaction")

            RichTextView(viewModel: .init(string: TextRendererHTML(html: String(data: html, encoding: .utf8)!).render()))
                .previewLayout(.fixed(width: 1160, height: 2000)) // Disable interaction to view it
                .previewDisplayName("HTML (Raw)")

#if os(iOS) || os(macOS)
            WebView(data: html, contentType: "application/html")
                .previewDisplayName("HTML")
#endif

#if os(iOS)
            PDFKitRepresentedView(document: PDFDocument(data: try! TextUtilities.pdf(from: string))!)
                .previewDisplayName("PDF")
#endif
        }
    }
}

private let task = LoggerStore.preview.entity(for: .login)
#endif

struct NetworkContent: OptionSet {
    let rawValue: Int16
    init(rawValue: Int16) { self.rawValue = rawValue }

    static let header = NetworkContent(rawValue: 1 << 0)
    static let largeHeader = NetworkContent(rawValue: 1 << 1)
    static let taskDetails = NetworkContent(rawValue: 1 << 2)
    static let requestComponents = NetworkContent(rawValue: 1 << 3)
    static let requestQueryItems = NetworkContent(rawValue: 1 << 4)
    static let errorDetails = NetworkContent(rawValue: 1 << 5)
    static let originalRequestHeaders = NetworkContent(rawValue: 1 << 6)
    static let currentRequestHeaders = NetworkContent(rawValue: 1 << 7)
    static let requestOptions = NetworkContent(rawValue: 1 << 8)
    static let requestBody = NetworkContent(rawValue: 1 << 9)
    static let responseHeaders = NetworkContent(rawValue: 1 << 10)
    static let responseBody = NetworkContent(rawValue: 1 << 11)

    static let sharing: NetworkContent = [
        largeHeader, taskDetails, errorDetails, currentRequestHeaders, requestBody, responseHeaders, responseBody
    ]

    static let all: NetworkContent = [
        largeHeader, taskDetails, errorDetails, requestComponents, requestQueryItems, errorDetails, originalRequestHeaders, currentRequestHeaders, requestOptions, requestBody, responseHeaders, responseBody
    ]
}
