// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

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
            message
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
            .font(ConsoleConstants.fontInfo)
            .foregroundColor(.secondary)
            .monospacedDigit()
    }

    private var message: some View {
        VStack(spacing: 3) {
            HStack {
                Text(ConsoleViewDelegate.getTitle(for: task) ?? "–")
                    .font(contentFont)
                    .foregroundColor(.primary)
                    .lineLimit(settings.displayOptions.contentLineLimit)

                Spacer()
            }
        }
    }

    private var contentFont: Font {
        .system(size: CGFloat(settings.displayOptions.contentFontSize) * fontMultiplier)
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
            .font(ConsoleConstants.fontInfo)
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

    private func makeInfoText(_ image: String, _ text: String) -> Text {
        Text(Image(systemName: image)).fontWeight(.light) + Text(" " + text)
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
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

@available(iOS 15, visionOS 1.0, *)
struct MockBadgeView: View {
    var body: some View {
        Text("MOCK")
#if os(watchOS)
            .font(.footnote)
#elseif os(tvOS)
            .font(.caption2)
#else
            .font(ConsoleConstants.fontInfo)
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
