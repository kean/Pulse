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
        var isNetworkExpanded = false
        var fontSize: CGFloat = 13
    }

    private let options: Options
    private let helpers: TextRenderingHelpers
    private var messages: [LoggerMessageEntity] = []

    init(options: Options = .init()) {
        self.options = options
        self.helpers = TextRenderingHelpers(options: options)
    }

    func render(_ entities: [NetworkTaskEntity]) -> NSAttributedString {
        messages = entities.compactMap(\.message)
        defer { messages = [] }
        return makeText()
    }

    func render(_ entities: [LoggerMessageEntity]) -> NSAttributedString {
        messages = entities
        defer { messages = [] }
        return makeText()
    }

    func makeText(indices: Range<Int>? = nil) -> NSAttributedString {
        makeText(indices: indices ?? messages.indices, options: options, helpers: helpers)
    }

    private func makeText(indices: Range<Int>, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        let text = NSMutableAttributedString()
        let lastIndex = messages.count - 1
        for index in indices {
            text.append(makeText(for: messages[index], index: index, options: options, helpers: helpers))
            if index != lastIndex {
                text.append("\n", helpers.titleAttributes)
            }
        }
        return text
    }

    private func makeText(for message: LoggerMessageEntity, index: Int, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        if let task = message.task {
            return makeText(for: message, task: task, index: index, options: options, helpers: helpers)
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
        text.append(message.text, textAttributes)

        return text
    }

    private func makeText(for message: LoggerMessageEntity, task: NetworkTaskEntity, index: Int, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        let text = NSMutableAttributedString()

        let state = task.state

        func makeTitle() -> String {
            let time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)
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

        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        let textAttributes = helpers.textAttributes[level]!
        let messageText = task.url ?? "–"

        text.append(messageText + " ", textAttributes)

        if options.isNetworkExpanded, let data = task.responseBody?.data {
            text.append("\n")
            text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
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
private final class TextRenderingHelpers {
    let ps: NSParagraphStyle
    let titleAttributes: [NSAttributedString.Key: Any]
    private(set) var textAttributes: [LoggerStore.Level: [NSAttributedString.Key: Any]] = [:]

    let showAllAttributes: [NSAttributedString.Key: Any]

    init(options: ConsoleTextRenderer.Options) {
        let lineHeight = geLineHeight(for: Int(options.fontSize))
        let ps = NSParagraphStyle.make(lineHeight: lineHeight)
        self.ps = ps

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

        self.showAllAttributes = [
            .font: UXFont.monospacedSystemFont(ofSize: options.fontSize, weight: .regular),
            .foregroundColor: UXColor.systemBlue,
            .paragraphStyle: ps
        ]

        func makeLabelAttributes(level: LoggerStore.Level) -> [NSAttributedString.Key: Any] {
            let textColor = level == .trace ? .secondaryLabel : UXColor(ConsoleMessageStyle.textColor(level: level))
            return [
                .font: UXFont.systemFont(ofSize: 15),
//                .font: UXFont.monospacedSystemFont(ofSize: options.fontSize, weight: .regular),
                .foregroundColor: textColor,
                .paragraphStyle: ps
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
