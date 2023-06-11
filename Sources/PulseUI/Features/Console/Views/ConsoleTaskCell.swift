// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

@available(iOS 15, *)
struct ConsoleTaskCell: View {
    @ObservedObject var task: NetworkTaskEntity
    var isDisclosureNeeded = false

    @ObservedObject private var settings: UserSettings = .shared

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
#if os(iOS)
            requestHeaders
#endif
        }
#if !PULSE_STANDALONE_APP
            .animation(.default, value: task.state)
#endif
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
        HStack {
            (Text(Image(systemName: task.state.iconSystemName)) + Text(" " + ConsoleFormatter.status(for: task)))
                .font(ConsoleConstants.fontTitle)
                .fontWeight(.medium)
                .foregroundColor(task.state.tintColor)
                .lineLimit(1)
#if os(macOS)
            details
#endif
            Spacer()
#if os(iOS) || os(macOS)
            PinView(task: task)
#endif
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
                Text(task.url ?? "–")
                    .font(ConsoleConstants.fontBody)
                    .foregroundColor(.primary)
                    .lineLimit(settings.lineLimit)

                Spacer()
            }
        }
    }

    private var details: some View {
#if os(watchOS)
        HStack {
            Text(task.httpMethod ?? "GET")
                .font(ConsoleConstants.fontBody)
                .foregroundColor(.secondary)
            Spacer()
            time
        }
#elseif os(iOS)
        infoText
            .lineLimit(1)
            .font(ConsoleConstants.fontInfo)
            .foregroundColor(.secondary)
            .padding(.top, 2)
#else
        infoText
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
#endif
    }

    private var infoText: Text {
        var text = Text(task.httpMethod ?? "GET")
        if task.state != .pending {
            text = text + Text("    ") +
            makeInfoText("arrow.up", byteCount(for: task.requestBodySize)) + Text("    ") +
            makeInfoText("arrow.down", byteCount(for: task.responseBodySize)) + Text("     ") +
            makeInfoText("clock", ConsoleFormatter.duration(for: task) ?? "–")
        }
        return text
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

private struct ConsoleProgressText: View {
    let title: String
    @ObservedObject var viewModel: ProgressViewModel

    var body: some View {
        (Text(title) +
         Text("   ") +
         Text(viewModel.details ?? ""))
            .font(ConsoleConstants.fontBody.smallCaps())
            .lineLimit(1)
            .foregroundColor(.secondary)
    }
}

#if DEBUG
@available(iOS 15, *)
struct ConsoleTaskCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleTaskCell(task: LoggerStore.preview.entity(for: .login))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
