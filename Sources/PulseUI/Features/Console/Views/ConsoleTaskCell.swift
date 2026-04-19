// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

package struct ConsoleTaskCell: View {
    @ObservedObject var task: NetworkTaskEntity
    var isDisclosureNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    package enum EditableArea {
        case header, content, footer
    }

    package var highlightedArea: EditableArea?

    package var urlMatch: ConsoleSearchMatch?

    package init(task: NetworkTaskEntity, isDisclosureNeeded: Bool = false, highlightedArea: EditableArea? = nil) {
        self.task = task
        self.isDisclosureNeeded = isDisclosureNeeded
        self.highlightedArea = highlightedArea
    }

    package consuming func urlMatch(_ match: ConsoleSearchMatch?) -> ConsoleTaskCell {
        self.urlMatch = match
        return self
    }

    package var body: some View {
        let displayOptions = environment.listDisplayOptions(for: task)
        VStack(alignment: .leading, spacing: 4) {
            makeHeader(settings: displayOptions.header)
            Group {
                if let custom = environment.delegate?.console(contentViewFor: task) {
                    custom
                } else {
                    makeContent(settings: displayOptions.content)
                }
            }
            .highlighted(highlightedArea == .content)
#if os(iOS) || os(watchOS)
            makeFooter(settings: displayOptions.footer)
                .highlighted(highlightedArea == .footer)
#endif
        }
    }

    // MARK: – Header

#if os(watchOS)
    private func makeHeader(settings: ConsoleListDisplaySettings.HeaderSettings) -> some View {
        HStack {
            StatusIndicatorView(state: task.state(in: store))
            makeInfo(settings: settings)
        }
    }
#else
    private func makeHeader(settings: ConsoleListDisplaySettings.HeaderSettings) -> some View {
        HStack(spacing: 6) {
            if task.isMocked {
                MockBadgeView()
            }
            makeInfo(settings: settings).highlighted(highlightedArea == .header)

            Spacer()
            if task.isPinned {
                BookmarkIconView()
            }
            ConsoleTimestampView(timestamp: task.formattedTimestamp)
                .padding(.trailing, 3)
        }
        .overlay(alignment: .leading) {
            StatusIndicatorView(state: task.state(in: store))
#if os(tvOS)
                .offset(x: -20)
#else
                .offset(x: -14)
#endif
        }
        .overlay(alignment: .trailing) {
            if isDisclosureNeeded {
                ListDisclosureIndicator()
                    .offset(x: 8)
            }
        }
    }

#endif
    private func makeInfo(settings: ConsoleListDisplaySettings.HeaderSettings) -> some View {
        let font = makeFont(size: settings.fontSize)
        var attributed = AttributedString(ConsoleFormatter.status(for: task, store: store))
        attributed.font = font.weight(.medium)
        attributed.foregroundColor = task.state == .failure ? .red : .primary

#if os(watchOS)
        return Text(attributed) // Not enough space for anything else
#else
        let details = settings.fields
            .compactMap { environment.makeInfoText(for: $0, task: task) }
            .joined(separator: " · ")
        if !details.isEmpty {
            var detailsAttr = AttributedString(" · \(details)")
            detailsAttr.font = font
            attributed.append(detailsAttr)
        }
        return Text(attributed)
            .lineLimit(settings.lineLimit)
            .foregroundStyle(.secondary)
#endif
    }

    // MARK: – Content

    private func makeContent(settings: ConsoleListDisplaySettings.ContentSettings) -> some View {
        let design: Font.Design? = settings.isMonospaced ? .monospaced : nil
        let font = makeFont(size: settings.fontSize, design: design)

        let content = environment.formattedContent(for: task, settings: settings) ?? "–"
        var main = makeHighlightedContent(content)
        main.font = font

        let attributed: AttributedString
        if settings.showMethod, let method = task.httpMethod {
            var methodAttr = AttributedString(method.appending(" "))
            methodAttr.font = font.weight(.medium).smallCaps()
            methodAttr.append(main)
            attributed = methodAttr
        } else {
            attributed = main
        }

        return Text(attributed)
            .lineLimit(settings.lineLimit)
    }

    // MARK: – Footer

    @ViewBuilder
    private func makeFooter(settings: ConsoleListDisplaySettings.FooterSettings) -> some View {
        let design: Font.Design? = settings.isMonospaced ? .monospaced : nil
        let fields = settings.fields.compactMap { environment.makeInfoText(for: $0, task: task) }
        if !fields.isEmpty {
            Text(fields.joined(separator: " · "))
                .lineLimit(settings.lineLimit)
                .font(makeFont(size: settings.fontSize, design: design))
                .foregroundStyle(.secondary)
        }
        let additional = settings.additionalFields.compactMap { environment.makeInfoItem(for: $0, task: task) }
        if !additional.isEmpty {
            Divider().opacity(0.5).padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(additional) { field in
                    (Text(field.title + ": ").fontWeight(.medium) + Text(field.value))
                        .lineLimit(settings.lineLimit)
                        .font(makeFont(size: settings.fontSize, design: design))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func makeHighlightedContent(_ content: String) -> AttributedString {
        var attributed = AttributedString(content)
        guard let urlMatch else { return attributed }
        let matchedText = String(urlMatch.line[urlMatch.range])
        guard !matchedText.isEmpty, let range = attributed.range(of: matchedText) else {
            return attributed
        }
        attributed.foregroundColor = .secondary
        attributed[range].foregroundColor = .primary
        return attributed
    }

    private func makeFont(size: Int, weight: Font.Weight? = nil, design: Font.Design? = nil) -> Font {
        if #available(iOS 16, tvOS 16, *) {
            return Font.system(size: CGFloat(design == .monospaced ? size - 1 : size) * fontMultiplier, weight: weight, design: design)
        } else {
            return Font.system(size: CGFloat(design == .monospaced ? size - 1 : size) * fontMultiplier)
        }
    }
}

#if canImport(RiftSupport)
import RiftSupport

private extension View {
    @ViewBuilder
    func highlighted(_ isHighlighted: Bool) -> some View {
        if isHighlighted {
            self.highlighted()
        } else {
            self
        }
    }
}
#else
private extension View {
    func highlighted(_ isHighlighted: Bool) -> some View {
        self
    }
}
#endif

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview(traits: .sizeThatFitsLayout) {
    ConsoleTaskCell(task: LoggerStore.preview.entity(for: .login))
        .padding()
        .injecting(ConsoleEnvironment(store: LoggerStore.preview))
}
#endif
