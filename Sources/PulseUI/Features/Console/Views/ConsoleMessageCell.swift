// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

package struct ConsoleMessageCell: View {
    package let message: LoggerMessageEntity
    package var isDisclosureNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 17.0
    @ObservedObject private var settings: UserSettings = .shared

    package init(message: LoggerMessageEntity, isDisclosureNeeded: Bool = false) {
        self.message = message
        self.isDisclosureNeeded = isDisclosureNeeded
    }

    package var body: some View {
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
#if !os(watchOS)
            if message.isPinned {
                BookmarkIconView()
            }
            ConsoleTimestampView(timestamp: message.formattedTimestamp)
                .padding(.trailing, 3)
#endif
        }
        .overlay(alignment: .trailing) {
            if isDisclosureNeeded {
                ListDisclosureIndicator()
                    .offset(x: 8, y: 0)
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
        let baseSize = CGFloat(settings.listDisplayOptions.content.fontSize)
        return Font.system(size: baseSize * (fontMultiplier / 17.0))
    }

    private var detailsFont: Font {
        let baseSize = CGFloat(settings.listDisplayOptions.header.fontSize)
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
    package static func textColor(for level: LoggerStore.Level) -> UXColor {
        switch level {
        case .trace: return .secondaryLabel
        case .debug, .info: return .label
        case .notice, .warning: return .systemOrange
        case .error, .critical: return .red
        }
    }
}

extension Color {
    package static func textColor(for level: LoggerStore.Level) -> Color {
        switch level {
        case .trace: return .secondary
        case .debug, .info: return .primary
        case .notice, .warning: return .orange
        case .error, .critical: return .red
        }
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview(traits: .sizeThatFitsLayout) {
    ConsoleMessageCell(message: try! LoggerStore.mock.messages()[0])
        .injecting(ConsoleEnvironment(store: LoggerStore.mock))
        .padding()
}
#endif
