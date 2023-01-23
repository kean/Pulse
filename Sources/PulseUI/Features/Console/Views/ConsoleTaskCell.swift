// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

struct ConsoleTaskCell: View {
    @StateObject private var viewModel = ConsoleTaskCellViewModel()

    let task: NetworkTaskEntity
    var isDisclosureNeeded: Bool

    init(task: NetworkTaskEntity, isDisclosureNeeded: Bool = false) {
        self.task = task
        self.isDisclosureNeeded = isDisclosureNeeded
    }

    var body: some View {
        let contents = VStack(alignment: .leading, spacing: 6) {
            title
            message
            if task.state == .pending {
                ConsoleProgressText(title: task.httpMethod ?? "GET", viewModel: ProgressViewModel(task: task))
            } else {
                details
            }
        }
            .onAppear { viewModel.bind(task)}
            .onChange(of: task) { viewModel.bind($0) }
#if os(macOS)
        contents.padding(.vertical, 4)
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
        Text(ConsoleMessageCellViewModel.timeFormatter.string(from: task.createdAt))
            .font(ConsoleConstants.fontTitle)
#if os(watchOS)
            .foregroundColor(.secondary)
#else
            .foregroundColor(task.state == .failure ? .red : .secondary)
#endif
            .lineLimit(1)
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
#else
        detailsText
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
#endif
    }

    private var detailsText: Text {
        Text(task.httpMethod ?? "GET").font(ConsoleConstants.fontBody.smallCaps()) +
         Text("   ") +
        Text(Image(systemName: "arrow.up")).fontWeight(.light) +
        Text(" " + byteCount(for: task.requestBodySize)) +
        Text("   ") +
        Text(Image(systemName: "arrow.down")).fontWeight(.light) +
        Text(" " + byteCount(for: task.responseBodySize)) +
        Text("   ") +
        Text(Image(systemName: "clock")).fontWeight(.light) +
        Text(" " + (ConsoleFormatter.duration(for: task) ?? "–"))
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
    }
}

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
