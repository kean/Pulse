// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

@available(iOS 15, visionOS 1.0, *)
struct ConsoleMessageCell: View {
    let message: LoggerMessageEntity
    var isDisclosureNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 17.0
    @ObservedObject private var settings: UserSettings = .shared

    var body: some View {
        let contents = VStack(alignment: .leading, spacing: 4) {
            header.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            Text(message.text)
                .font(contentFont)
                .foregroundColor(.textColor(for: message.logLevel))
                .lineLimit(settings.lineLimit)
        }
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text(title)
                .lineLimit(1)
                .font(.footnote)
                .foregroundColor(titleColor)
            Spacer()
            Components.makePinView(for: message)
            HStack(spacing: 3) {
                ConsoleTimestampView(date: message.createdAt)
                    .overlay(alignment: .trailing) {
                        if isDisclosureNeeded {
                            ListDisclosureIndicator()
                                .offset(x: 11, y: 0)
                        }
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

    // MARK: - Helpers

    private var contentFont: Font {
        let baseSize = CGFloat(settings.displayOptions.contentFontSize)
        return Font.system(size: baseSize * (fontMultiplier / 17.0))
    }

    private var detailsFont: Font {
        let baseSize = CGFloat(settings.displayOptions.detailsFontSize)
        return Font.system(size: baseSize * (fontMultiplier / 17.0)).monospacedDigit()
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
            .lineLimit(1)
            .font(.caption2.weight(.bold))
            .foregroundColor(.secondary.opacity(0.33))
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
@available(iOS 15, visionOS 1.0, *)
struct ConsoleMessageCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleMessageCell(message: try! LoggerStore.mock.messages()[0])
            .injecting(ConsoleEnvironment(store: .mock))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

struct ConsoleConstants {
#if os(watchOS)
    static let fontTitle = Font.system(size: 14)
#elseif os(macOS)
    static let fontTitle = Font.subheadline
#elseif os(iOS) || os(visionOS)
    static let fontTitle = Font.subheadline.monospacedDigit()
#else
    static let fontTitle = Font.caption
#endif
}
