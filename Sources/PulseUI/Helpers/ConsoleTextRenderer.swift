// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import Pulse
import CoreData
import SwiftUI
import Pulse

/// Renders console messages as attributed strings.
@available(iOS 14.0, tvOS 14.0, *)
final class ConsoleTextRenderer {
    struct Options {
        var networkContent: NetworkContent = []
        var fontSize: CGFloat = 15
    }

    struct NetworkContent: OptionSet {
        let rawValue: Int16

        init(rawValue: Int16) {
            self.rawValue = rawValue
        }

        static let summary = NetworkContent(rawValue: 1 << 0)

        static let all: NetworkContent = [
            summary
        ]
    }

    private let options: Options
    private let helpers: TextRenderingHelpers

    init(options: Options = .init()) {
        self.options = options
        self.helpers = TextRenderingHelpers(options: options)
    }

    func render(_ entities: [NetworkTaskEntity]) -> NSAttributedString {
        joined(entities.map(render))
    }

    func render(_ entities: [LoggerMessageEntity]) -> NSAttributedString {
        joined(entities.map(render))
    }

    private func joined(_ strings: [NSAttributedString]) -> NSAttributedString {
        let output = NSMutableAttributedString()
        for string in strings {
            output.append(string)
        }
        return output
    }

    func render(_ message: LoggerMessageEntity) -> NSAttributedString {
        if let task = message.task {
            return render(task)
        }

        let text = NSMutableAttributedString()

        // Title
        let time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)
        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        let title = [time, level.name.capitalized, message.label.name.capitalized]
            .joined(separator: " · ")
        text.append(title + "\n", helpers.titleAttributes)

        // Text
        let textAttributes = helpers.textAttributes[level]!
        text.append(message.text + "\n", textAttributes)

        return text
    }

    func render(_ task: NetworkTaskEntity) -> NSAttributedString {
        let text = NSMutableAttributedString()

        let state = task.state

        func makeTitle() -> String {
            let time = ConsoleMessageViewModel.timeFormatter.string(from: task.createdAt)
            let status: String
            switch state {
            case .pending:
                status = "PENDING"
            case .success:
                status = StatusCodeFormatter.string(for: Int(task.statusCode))
            case .failure:
                if task.errorCode != 0 {
                    status = "\(task.errorCode) (\(descriptionForURLErrorCode(Int(task.errorCode))))"
                } else {
                    status = StatusCodeFormatter.string(for: Int(task.statusCode))
                }
            }
            var duration: String?
            if task.duration > 0 {
                duration = "\(DurationFormatter.string(from: task.duration))"
            }
            return [time, task.httpMethod, status, duration].compactMap { $0 }.joined(separator: " · ")
        }

        let tintColor: UXColor = {
            switch state {
            case .pending: return .systemYellow
            case .success: return .systemGreen
            case .failure: return Palette.red
            }
        }()

        text.append(makeTitle() + "\n", {
            var attributes = helpers.titleAttributes
            attributes[.foregroundColor] = tintColor
            return attributes
        }())

        func append(section: KeyValueSectionViewModel?) {
            guard let section = section else { return }
            text.append(section.title + "\n", helpers.titleAttributes)
            var keyAttributes = helpers.detailsAttributes
            keyAttributes[.font] = UXFont.systemFont(ofSize: options.fontSize, weight: .medium)
            keyAttributes[.foregroundColor] = UXColor(section.color)
            for (key, value) in section.items {
                text.append(key, keyAttributes)
                text.append(": \(value ?? "–")\n", helpers.detailsAttributes)
            }
        }

        if let url = task.url {
            text.append(url + "\n", helpers.textAttributes[.debug]!)
        }

        let viewModel = NetworkInspectorSummaryViewModel(task: task)
        let content = options.networkContent

        if content.contains(.all) {
            append(section: viewModel.errorModel)

            if viewModel.originalRequestSummary != nil {
                append(section: viewModel.originalRequestHeaders.title("Request Headers"))
                append(section: viewModel.originalRequestParameters?.title("Request Options"))
                if let data = task.requestBody?.data, !data.isEmpty {
                    text.append("Request Body\n", helpers.titleAttributes)
                    text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
                }
            }

            if let responseSummary = viewModel.responseSummary {
                append(section: responseSummary.title("Response Summary"))
                append(section: viewModel.responseHeaders.title("Response Headers"))
                if let data = task.responseBody?.data, !data.isEmpty {
                    text.append("Response Body\n", helpers.titleAttributes)
                    text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
                }
            }
        }
        return text
    }

    private func renderNetworkTaskBody(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?) -> NSAttributedString {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            let fontSize = options.fontSize - 1
            let renderer = AttributedStringJSONRenderer(fontSize: fontSize, lineHeight: geLineHeight(for: Int(fontSize)))
            let printer = JSONPrinter(renderer: renderer)
            printer.render(json: json, error: error)
            return renderer.make()
        } else if let string = String(data: data, encoding: .utf8) {
            if contentType?.isEncodedForm ?? false, let components = decodeQueryParameters(form: string) {
                return components.asAttributedString()
            } else if contentType?.isHTML ?? false {
                return HTMLPrettyPrint(string: string).render()
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
}

#warning("TODO: remove unused attributes")
@available(iOS 14.0, tvOS 14.0, *)
final class TextRenderingHelpers {
    let paragraphStyle: NSParagraphStyle
    let titleAttributes: [NSAttributedString.Key: Any]
    private(set) var textAttributes: [LoggerStore.Level: [NSAttributedString.Key: Any]] = [:]

    var detailsAttributes: [NSAttributedString.Key: Any] { textAttributes[.debug]! }

    init(options: ConsoleTextRenderer.Options) {
        let lineHeight = geLineHeight(for: Int(options.fontSize))
        self.paragraphStyle = NSParagraphStyle.make(lineHeight: lineHeight)

        self.titleAttributes = [
            .font: UXFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: UXColor.secondaryLabel,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.maximumLineHeight = lineHeight
                style.minimumLineHeight = lineHeight
                style.paragraphSpacingBefore = 12
                return style
            }()
        ]

        func makeLabelAttributes(level: LoggerStore.Level) -> [NSAttributedString.Key: Any] {
            let textColor = level == .trace ? .secondaryLabel : UXColor(ConsoleMessageStyle.textColor(level: level))
            return [
                .font: UXFont.systemFont(ofSize: options.fontSize),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        }

        for level in LoggerStore.Level.allCases {
            textAttributes[level] = makeLabelAttributes(level: level)
        }
    }
}

private func geLineHeight(for fontSize: Int) -> CGFloat {
    CGFloat(fontSize + 6)
}
