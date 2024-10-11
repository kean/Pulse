// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

package struct ConsoleTaskCell: View {
    @ObservedObject var task: NetworkTaskEntity
    var isDisclosureNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @Environment(\.store) private var store: LoggerStore

    package enum EditableArea {
        case header, content, footer
    }

    package var highlightedArea: EditableArea?

    package init(task: NetworkTaskEntity, isDisclosureNeeded: Bool = false, highlightedArea: EditableArea? = nil) {
        self.task = task
        self.isDisclosureNeeded = isDisclosureNeeded
        self.highlightedArea = highlightedArea
    }

    package var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            makeContent(settings: settings.listDisplayOptions.content)
                .highlighted(highlightedArea == .content)
#if os(iOS) || os(watchOS)
            makeFooter(settings: settings.listDisplayOptions.footer)
                .highlighted(highlightedArea == .footer)
#endif
        }
    }

    // MARK: – Header

#if os(watchOS)
    private var header: some View {
        HStack {
            StatusIndicatorView(state: task.state(in: store))
            info
        }
    }
#else
    private var header: some View {
        HStack(spacing: 6) {
            if task.isMocked {
                MockBadgeView()
            }
            info.highlighted(highlightedArea == .header)

            Spacer()
            if task.isPinned {
                BookmarkIconView()
            }
            ConsoleTimestampView(date: task.createdAt)
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
    private var info: some View {
        let status: Text = Text(ConsoleFormatter.status(for: task, store: store))
            .font(makeFont(size: settings.listDisplayOptions.header.fontSize).weight(.medium))
            .foregroundColor(task.state == .failure ? .red : .primary)

#if os(watchOS)
        return status // Not enough space for anything else
#else

        var text: Text {
            let details = settings.listDisplayOptions.header.fields
                .compactMap(task.makeInfoText)
                .joined(separator: " · ")
            guard !details.isEmpty else {
                return status
            }
            return status + Text(" · \(details)")
                .font(makeFont(size: settings.listDisplayOptions.header.fontSize))
        }
        return text
            .tracking(-0.1)
            .lineLimit(settings.listDisplayOptions.header.lineLimit)
            .foregroundStyle(.secondary)
#endif
    }

    // MARK: – Content

    private func makeContent(settings: ConsoleListDisplaySettings.ContentSettings) -> some View {
        let design: Font.Design? = settings.isMonospaced ? .monospaced : nil
        var method: Text? {
            guard settings.showMethod, let method = task.httpMethod else {
                return nil
            }
            return Text(method.appending(" "))
                .font(makeFont(size: settings.fontSize, design: design).weight(.medium).smallCaps())
                .tracking(-0.2)
        }

        var main: Text {
            Text(task.getFormattedContent(settings: settings) ?? "–")
                .font(makeFont(size: settings.fontSize, design: design))
        }

        var text: Text {
            if let method {
                method + main
            } else {
                main
            }
        }

        return text
            .lineLimit(settings.lineLimit)
    }

    // MARK: – Footer

    @ViewBuilder
    private func makeFooter(settings: ConsoleListDisplaySettings.FooterSettings) -> some View {
        let design: Font.Design? = settings.isMonospaced ? .monospaced : nil
        let fields = settings.fields.compactMap(task.makeInfoText)
        if !fields.isEmpty {
            Text(fields.joined(separator: " · "))
                .lineLimit(settings.lineLimit)
                .font(makeFont(size: settings.fontSize, design: design))
                .foregroundStyle(.secondary)
        }
        let additional = settings.additionalFields.compactMap(task.makeInfoItem)
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
@available(iOS 16, visionOS 1, *)
struct ConsoleTaskCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleTaskCell(task: LoggerStore.preview.entity(for: .login))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
