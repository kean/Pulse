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
        var isCompactMode = false
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
                if options.isCompactMode {
                    text.append("\n", helpers.digitalAttributes)
                } else {
                    text.append("\n\n", helpers.digitalAttributes)
                }
            }
        }
#warning("TODO: customize this")
        text.addAttributes([
            .paragraphStyle: NSParagraphStyle.make(lineHeight: lineHeight(for: Int(options.fontSize)))
        ])
        return text
    }

    private func makeToggleInfoURL(for id: NSManagedObjectID) -> URL {
        URL(string: "story://toggle-info/\(id.uriRepresentation().absoluteString)")!
    }

    private func getInterval(for message: LoggerMessageEntity) -> TimeInterval {
        guard let first = messages.first else { return 0 }
        return message.createdAt.timeIntervalSince1970 - first.createdAt.timeIntervalSince1970
    }

    private func makeText(for message: LoggerMessageEntity, index: Int, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        if let task = message.task {
            return makeText(for: message, task: task, index: index, options: options, helpers: helpers)
        }

        let text = NSMutableAttributedString()

        // Title
        let time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)

        // Title first part (digital)
        var titleFirstPart = "\(time) · "
        if !options.isCompactMode {
            let interval = getInterval(for: message)
            if interval < 3600 * 24 {
                titleFirstPart.append(contentsOf: "\(DurationFormatter.string(from: interval)) · ")
            }
        }
        text.append(titleFirstPart, helpers.digitalAttributes)

        // Title second part (regular)
        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        var titleSecondPart = options.isCompactMode ? "" : "\(level.name) · "
        titleSecondPart.append("\(message.label.name)")
        titleSecondPart.append(options.isCompactMode ? " " : "\n")
        text.append(titleSecondPart, helpers.titleAttributes)

        // Text
        let textAttributes = helpers.textAttributes[level]!
        if options.isCompactMode {
            if let newlineIndex = message.text.firstIndex(of: "\n") {
                text.append(message.text[..<newlineIndex] + " ", textAttributes)
                var moreAttr = helpers.showAllAttributes
                #warning("REMOVe")
                moreAttr[.link] = makeToggleInfoURL(for: message.objectID)
                text.append("Show More", moreAttr)
            } else {
                text.append(message.text, textAttributes)
            }
        } else {
            text.append(message.text, textAttributes)
        }

        return text
    }

    private func makeText(for message: LoggerMessageEntity, task: NetworkTaskEntity, index: Int, options: Options, helpers: TextRenderingHelpers) -> NSAttributedString {
        let text = NSMutableAttributedString()

        // Title
        let state = task.state
        let time = ConsoleMessageViewModel.timeFormatter.string(from: message.createdAt)
        var prefix: String
        switch state {
        case .pending:
            prefix = "PENDING"
        case .success:
            prefix = StatusCodeFormatter.string(for: Int(task.statusCode))
        case .failure:
            if task.errorCode != 0 {
                prefix = "\(task.errorCode) (\(descriptionForURLErrorCode(Int(task.errorCode))))"
            } else {
                prefix = StatusCodeFormatter.string(for: Int(task.statusCode))
            }
        }

        let tintColor: UXColor = {
            switch state {
            case .pending: return .systemYellow
            case .success: return .systemGreen
            case .failure: return Palette.red
            }
        }()

        var title = "\(prefix)"
        if task.duration > 0 {
            title += " · \(DurationFormatter.string(from: task.duration))"
        }

        text.append("\(time) · ", helpers.digitalAttributes)
        if !options.isCompactMode  {
            let interval = getInterval(for: message)
            if interval < 3600 * 24 {
                text.append("\(DurationFormatter.string(from: interval)) · ", helpers.digitalAttributes)
            }
        }
        text.append(title + " ", {
            var attributes = helpers.titleAttributes
            attributes[.foregroundColor] = tintColor
            return attributes
        }())
        //        text.append(title + " ", helpers.titleAttributes)
        text.append(options.isCompactMode ? " " : "\n", helpers.titleAttributes)

        // Text
        let level = LoggerStore.Level(rawValue: message.level) ?? .debug
        let textAttributes = helpers.textAttributes[level]!
        let method = task.httpMethod ?? "GET"
        let messageText = method + " " + (task.url ?? "–")

        text.append(messageText + " ", {
            var attributes = textAttributes
            attributes[.link] = makeToggleInfoURL(for: message.objectID)
            attributes[.underlineColor] = UXColor.systemBlue
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            attributes[.foregroundColor] = UXColor.systemBlue
            return attributes
        }())

        if options.isNetworkExpanded, let data = task.responseBody?.data {
            text.append("\n")
            text.append(renderNetworkTaskBody(data, contentType: task.responseContentType.map(NetworkLogger.ContentType.init), error: task.decodingError))
        }
        return text
    }

    private func renderNetworkTaskBody(_ data: Data, contentType: NetworkLogger.ContentType?, error: NetworkLogger.DecodingError?) -> NSAttributedString {
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) {
            let fontSize = options.fontSize - 1
            let renderer = AttributedStringJSONRenderer(fontSize: fontSize, lineHeight: lineHeight(for: Int(fontSize)))
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
    let digitalAttributes: [NSAttributedString.Key: Any]
    let titleAttributes: [NSAttributedString.Key: Any]
    private(set) var textAttributes: [LoggerStore.Level: [NSAttributedString.Key: Any]] = [:]

    let infoIconAttributes: [NSAttributedString.Key: Any]
    let showAllAttributes: [NSAttributedString.Key: Any]

    init(options: ConsoleTextRenderer.Options) {
        let ps = NSParagraphStyle.make(lineHeight: lineHeight(for: Int(options.fontSize)))
        self.ps = ps

        self.digitalAttributes = [
            .font: UXFont.monospacedSystemFont(ofSize: options.fontSize, weight: .regular),
            .foregroundColor: UXColor.secondaryLabel,
            .paragraphStyle: ps
        ]

        self.titleAttributes = [
            .font: UXFont.monospacedSystemFont(ofSize: options.fontSize, weight: .regular),
            .foregroundColor: UXColor.secondaryLabel,
            .paragraphStyle: ps
        ]

        var infoIconAttributes = titleAttributes
        infoIconAttributes[.foregroundColor] = UXColor.blue
        self.infoIconAttributes = infoIconAttributes

        self.showAllAttributes = [
            .font: UXFont.monospacedSystemFont(ofSize: options.fontSize, weight: .regular),
            .foregroundColor: UXColor.systemBlue,
            .paragraphStyle: ps
        ]

        func makeLabelAttributes(level: LoggerStore.Level) -> [NSAttributedString.Key: Any] {
            let textColor = level == .trace ? .secondaryLabel : UXColor(ConsoleMessageStyle.textColor(level: level))
            return [
                .font: UXFont.monospacedSystemFont(ofSize: options.fontSize, weight: .regular),
                .foregroundColor: textColor,
                .paragraphStyle: ps
            ]
        }

        for level in LoggerStore.Level.allCases {
            textAttributes[level] = makeLabelAttributes(level: level)
        }
    }
}

private func lineHeight(for fontSize: Int) -> CGFloat {
    CGFloat(fontSize + 6)
}
