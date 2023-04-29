// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, *)
struct ConsoleMessageCell: View {
    let message: LoggerMessageEntity
    var isDisclosureNeeded = false

    @ObservedObject private var settings: UserSettings = .shared

    var body: some View {
        let contents = VStack(alignment: .leading, spacing: 4) {
            header.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            Text(message.text)
                .font(ConsoleConstants.fontBody)
                .foregroundColor(.textColor(for: message.logLevel))
                .lineLimit(settings.lineLimit)
        }
#if os(macOS)
        contents.padding(.vertical, 5)
#else
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
#endif
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text(title)
                .lineLimit(1)
#if os(iOS)
                .font(ConsoleConstants.fontInfo.weight(.medium))
#else
                .font(ConsoleConstants.fontTitle.weight(.medium))
#endif
                .foregroundColor(titleColor)
            Spacer()
#if os(macOS) || os(iOS)
            PinView(message: message)
#endif
            HStack(spacing: 3) {
                Text(ConsoleMessageCell.timeFormatter.string(from: message.createdAt))
                    .lineLimit(1)
                    .font(ConsoleConstants.fontInfo)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                if isDisclosureNeeded {
                    ListDisclosureIndicator()
                }
            }
        }
    }

    private var title: String {
        var title = message.logLevel.name.capitalized
        if message.label != "default" {
            title += "・\(message.label.capitalized)"
        }
        return title
    }

    var titleColor: Color {
        message.logLevel >= .warning ? .textColor(for: message.logLevel) : .secondary
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

struct ListDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(.separator)
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
            .padding(.trailing, -12)
    }
}

extension UXColor {
    static func textColor(for level: LoggerStore.Level) -> UXColor {
        switch level {
        case .trace: return .secondaryLabel
        case .debug, .info: return .label
        case .notice, .warning: return .systemOrange
        case .error, .critical: return .red
        }
    }
}

extension Color {
    static func textColor(for level: LoggerStore.Level) -> Color {
        switch level {
        case .trace: return .secondary
        case .debug, .info: return .primary
        case .notice, .warning: return .orange
        case .error, .critical: return .red
        }
    }
}

#if DEBUG
@available(iOS 15, *)
struct ConsoleMessageCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleMessageCell(message: try! LoggerStore.mock.allMessages()[0])
            .injecting(ConsoleEnvironment(store: .mock))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

struct ConsoleConstants {
#if os(watchOS)
    static let fontTitle = Font.system(size: 14)
    static let fontInfo = Font.system(size: 14)
    static let fontBody = Font.system(size: 15)
#elseif os(macOS)
    static let fontTitle = Font.caption
    static let fontInfo = Font.caption
    static let fontBody = Font.body
#elseif os(iOS)
    static let fontTitle = Font.subheadline.monospacedDigit()
    static let fontInfo = Font.caption.monospacedDigit()
    static let fontBody = Font.callout
#else
    static let fontTitle = Font.caption
    static let fontInfo = Font.caption
    static let fontBody = Font.caption
#endif
}
