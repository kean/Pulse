// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

#if os(iOS)

@available(iOS 15, visionOS 1.0, *)
struct ConsoleTaskCell: View {
    @ObservedObject var task: NetworkTaskEntity
    var isDisclosureNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @Environment(\.store) private var store: LoggerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            header
            details
            content.padding(.top, 3)
        }
    }

    // MARK: – Header

    private var header: some View {
        HStack(spacing: 6) {
            if task.isMocked {
                MockBadgeView()
            }
            info
            Spacer()
            ConsoleTimestampView(date: task.createdAt)
        }
        .overlay(alignment: .leading) {
            StatusIndicatorView(state: task.state(in: store))
                .offset(x: -14)
        }
        .overlay(alignment: .trailing) {
            if isDisclosureNeeded {
                ListDisclosureIndicator()
                    .offset(x: 11)
            }
        }
    }

    private var info: some View {
        var text: Text {
            let status: Text = Text(ConsoleFormatter.status(for: task, store: store))
                .font(.footnote.weight(.medium))
                .foregroundColor(task.state == .failure ? .red : .primary)

            guard settings.displayOptions.isShowingDetails else {
                return status
            }
            let details = settings.displayOptions.detailsFields
                .compactMap(makeInfoText)
                .joined(separator: " · ")
            guard !details.isEmpty else {
                return status
            }
            return status + Text(" · \(details)").font(.footnote)
        }
        return text
            .tracking(-0.1)
            .lineLimit(1)
            .foregroundStyle(.secondary)
    }


    private func makeInfoText(for detail: DisplayOptions.Field) -> String? {
        switch detail {
        case .method: 
            task.httpMethod
        case .requestSize:
            byteCount(for: task.requestBodySize)
        case .responseSize:
            byteCount(for: task.responseBodySize)
        case .responseContentType:
            task.responseContentType.map(NetworkLogger.ContentType.init)?.lastComponent.uppercased()
        case .duration:
            ConsoleFormatter.duration(for: task)
        case .host:
            task.host
        case .statusCode:
            task.statusCode != 0 ? task.statusCode.description : nil
        case .taskType:
            NetworkLogger.TaskType(rawValue: task.taskType)?.urlSessionTaskClassName
        case .taskDescription:
            task.taskDescription
        }
    }

    // MARK: – Details

    @ViewBuilder
    private var details: some View {
        if let host = task.host, !host.isEmpty {
            Text(host)
                .lineLimit(1)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: – Content

    private var content: some View {
        var method: Text? {
            guard let method = task.httpMethod else {
                return nil
            }
            return Text(method.appending(" "))
                .font(contentFont.weight(.medium).smallCaps())
                .tracking(-0.3)
        }

        var main: Text {
            Text(task.getFormattedContent(options: settings.displayOptions) ?? "–")
                .font(contentFont)
        }

        var text: Text {
            if let method {
                method + main
            } else {
                main
            }
        }

        return text
            .lineLimit(settings.displayOptions.contentLineLimit)
    }

    // MARK: - Helpers

    private var contentFont: Font {
        let baseSize = CGFloat(settings.displayOptions.contentFontSize)
        return Font.system(size: baseSize * fontMultiplier)
    }

    private var detailsFont: Font {
        let baseSize = CGFloat(settings.displayOptions.detailsFontSize)
        return Font.system(size: baseSize * fontMultiplier).monospacedDigit()
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
    }
}

private struct StatusIndicatorView: View {
    let state: NetworkTaskEntity.State?

    var body: some View {
        Image(systemName: "circle.fill")
            .foregroundStyle(color)
            .font(.system(size: 8))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var color: Color {
        guard let state else {
            return .secondary
        }
        switch state {
        case .pending: return .orange
        case .success: return .green
        case .failure: return .red
        }
    }
}

struct ConsoleTimestampView: View {
    let date: Date

    var body: some View {
        Text(ConsoleMessageCell.timeFormatter.string(from: date))
            .font(.caption)
            .monospacedDigit()
            .tracking(-0.5)
            .foregroundStyle(.secondary)
    }
}

#else

@available(iOS 15, visionOS 1.0, *)
struct ConsoleTaskCell: View {
    @ObservedObject var task: NetworkTaskEntity
    var isDisclosureNeeded = false

    @ScaledMetric(relativeTo: .body) private var fontMultiplier = 1.0
    @ObservedObject private var settings: UserSettings = .shared
    @Environment(\.store) private var store: LoggerStore

    var body: some View {
#if os(macOS)
        let spacing: CGFloat = 3
#else
        let spacing: CGFloat = 6
#endif

        let contents = VStack(alignment: .leading, spacing: spacing) {
            title.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            content
#if !os(macOS)
            details
#endif
#if os(iOS) || os(visionOS)
            requestHeaders
#endif
        }
        .animation(.default, value: task.state)
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

    private var title: some View {
        HStack(spacing: titleSpacing) {
            if task.isMocked {
                MockBadgeView()
                    .padding(.trailing, 2)
            }
            StatusLabelViewModel(task: task, store: store).text
                .font(ConsoleConstants.fontTitle)
                .fontWeight(.medium)
                .foregroundColor(task.state.tintColor)
                .lineLimit(1)
#if os(macOS)
            details
#endif
            Spacer()
            Components.makePinView(for: task)
#if !os(watchOS)
            HStack(spacing: 3) {
                time
                if isDisclosureNeeded {
                    ListDisclosureIndicator()
                }
            }
#endif
        }
    }

    private var time: some View {
        Text(ConsoleMessageCell.timeFormatter.string(from: task.createdAt))
            .lineLimit(1)
            .font(detailsFont)
            .foregroundColor(.secondary)
            .monospacedDigit()
    }

    private var content: some View {
        Text(task.getFormattedContent(options: settings.displayOptions) ?? "–")
            .font(contentFont)
            .lineLimit(settings.displayOptions.contentLineLimit)
            .foregroundColor(.primary)
    }

    @ViewBuilder
    private var details: some View {
#if os(watchOS)
        HStack {
            Text(task.httpMethod ?? "GET")
                .font(contentFont)
                .foregroundColor(.secondary)
            Spacer()
            time
        }
#elseif os(iOS) || os(visionOS)
        infoText?
            .lineLimit(settings.displayOptions.detailsLineLimit)
            .font(detailsFont)
            .foregroundColor(.secondary)
            .padding(.top, 2)
#else
        infoText?
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
#endif
    }

    private var infoText: Text? {
        guard settings.displayOptions.isShowingDetails else {
            return nil
        }
        var text = Text("")
        var isEmpty = true
        for detail in settings.displayOptions.detailsFields {
            if let value = makeText(for: detail) {
                if !isEmpty {
                    text = text + Text("   ")
                }
                isEmpty = false
                text = text + value
            }
        }
        return isEmpty ? nil : text
    }

    private func makeText(for detail: DisplayOptions.Field) -> Text? {
        switch detail {
        case .method: 
            Text(task.httpMethod ?? "GET")
        case .requestSize: 
            makeInfoText("arrow.up", byteCount(for: task.requestBodySize))
        case .responseSize:
            makeInfoText("arrow.down", byteCount(for: task.responseBodySize))
        case .responseContentType:
            task.responseContentType.map(NetworkLogger.ContentType.init).map {
                Text($0.lastComponent.uppercased())
            }
        case .duration:
            ConsoleFormatter.duration(for: task).map { makeInfoText("clock", $0) }
        case .host: 
            task.host.map { Text($0) }
        case .statusCode: 
            task.statusCode != 0 ? Text(task.statusCode.description) : nil
        case .taskType: 
            NetworkLogger.TaskType(rawValue: task.taskType).map {
                Text($0.urlSessionTaskClassName)
            }
        case .taskDescription:
            task.taskDescription.map { Text($0) }
        }
    }

    @ViewBuilder
    private var requestHeaders: some View {
        let headerValueMap = settings.displayHeaders.reduce(into: [String: String]()) { partialResult, header in
            partialResult[header] = task.originalRequest?.headers[header]
        }
        ForEach(headerValueMap.keys.sorted(), id: \.self) { key in
            HStack {
                (Text(key + ": ")
                    .foregroundColor(.secondary) +
                 Text(headerValueMap[key] ?? "-"))
                .font(.footnote)
                .allowsTightening(true)
                .lineLimit(3)

                Spacer()
            }
            .padding(.top, 6)
            .padding(.trailing, -7)
        }
    }

    // MARK: - Helpers

    private var contentFont: Font {
        let baseSize = CGFloat(settings.displayOptions.contentFontSize)
        return Font.system(size: baseSize * fontMultiplier)
    }
    
    private var detailsFont: Font {
        let baseSize = CGFloat(settings.displayOptions.detailsFontSize)
        return Font.system(size: baseSize * fontMultiplier).monospacedDigit()
    }

    private func makeInfoText(_ image: String, _ text: String) -> Text {
        Text(Image(systemName: image)).fontWeight(.light) + Text(" " + text)
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
    }
}

#if os(macOS)
private let infoSpacing: CGFloat = 8
#else
private let infoSpacing: CGFloat = 14
#endif

#if os(tvOS)
private let titleSpacing: CGFloat = 20
#else
private let titleSpacing: CGFloat? = nil
#endif

#endif

#if os(iOS)
@available(iOS 15, visionOS 1.0, *)
struct MockBadgeView: View {
    var body: some View {
        Text("MOCK")
            .foregroundStyle(.background)
            .font(.caption2.weight(.semibold))
            .padding(EdgeInsets(top: 2, leading: 5, bottom: 1, trailing: 5))
            .background(Color.secondary.opacity(0.66))
            .clipShape(Capsule())
    }
}
#else
@available(iOS 15, visionOS 1.0, *)
struct MockBadgeView: View {
    var body: some View {
        Text("MOCK")
#if os(watchOS)
            .font(.footnote)
#elseif os(tvOS)
            .font(.caption2)
#else
            .font(ConsoleConstants.fontTitle)
            .fontWeight(.medium)
#endif
            .foregroundStyle(Color.white)
            .background(background)
    }

    private var background: some View {
        Capsule()
            .foregroundStyle(Color.indigo)
            .padding(-2)
            .padding(.horizontal, -3)
#if os(tvOS)
            .padding(-2)
#endif
    }
}
#endif

#if DEBUG
@available(iOS 15, visionOS 1.0, *)
struct ConsoleTaskCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleTaskCell(task: LoggerStore.preview.entity(for: .login))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

