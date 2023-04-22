// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

struct ConsoleTaskCell: View {
    @ObservedObject var task: NetworkTaskEntity
    var isDisclosureNeeded: Bool

    init(task: NetworkTaskEntity, isDisclosureNeeded: Bool = false) {
        self.task = task
        self.isDisclosureNeeded = isDisclosureNeeded
    }

    var body: some View {
#if os(macOS)
        let spacing: CGFloat = 3
#else
        let spacing: CGFloat = 6
#endif

        let contents = VStack(alignment: .leading, spacing: spacing) {
            if #available(iOS 15, tvOS 15, *) {
                title.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            } else {
                title
            }
            message
#if !os(macOS)
            details
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
            .backport.monospacedDigit()
    }

    private var message: some View {
        Text(task.url ?? "–")
            .font(ConsoleConstants.fontBody)
            .foregroundColor(.primary)
            .lineLimit(ConsoleSettings.shared.lineLimit)
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
        HStack(spacing: infoSpacing) {
            Text(task.httpMethod ?? "GET")
                .fontWeight(.medium)
                .font(ConsoleConstants.fontInfo)

            Spacer()

            if task.state != .pending {
                makeInfoView(image: "arrow.up", text: byteCount(for: task.requestBodySize))
                makeInfoView(image: "arrow.down", text: byteCount(for: task.responseBodySize))
                makeInfoView(image: "clock", text: ConsoleFormatter.duration(for: task) ?? "–")
            }
        }
        .lineLimit(1)
        .foregroundColor(.secondary)
        .padding(.top, 2)
#else
        HStack(spacing: infoSpacing) {
            Text(task.httpMethod ?? "GET")

            if task.state != .pending {
                makeInfoView(image: "arrow.up", text: byteCount(for: task.requestBodySize))
                makeInfoView(image: "arrow.down", text: byteCount(for: task.responseBodySize))
                makeInfoView(image: "clock", text: ConsoleFormatter.duration(for: task) ?? "–")
            }

            Spacer()
        }
        .lineLimit(1)
        .font(ConsoleConstants.fontTitle)
        .foregroundColor(.secondary)
#endif
    }

    private func makeInfoView(image: String, text: String) -> some View {
        (Text(Image(systemName: image)).fontWeight(.light) +
         Text(" " + text))
        .font(ConsoleConstants.fontInfo)
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
struct ConsoleTaskCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleTaskCell(task: LoggerStore.preview.entity(for: .login))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
