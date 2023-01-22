// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

struct ConsoleTaskCell: View {
    @ObservedObject var viewModel: ConsoleTaskCellViewModel
    @ObservedObject var progressViewModel: ProgressViewModel
    let isDisclosureNeeded: Bool

    init(viewModel: ConsoleTaskCellViewModel, isDisclosureNeeded: Bool = false) {
        self.viewModel = viewModel
        self.progressViewModel = viewModel.progress
        self.isDisclosureNeeded = isDisclosureNeeded
    }

    var body: some View {
        let contents = VStack(alignment: .leading, spacing: 6) {
            title
            message
            if viewModel.task.state == .pending {
                Text(ConsoleFormatter.progress(for: viewModel.task) ?? "...")
                    .lineLimit(1)
                    .font(ConsoleConstants.fontTitle)
                    .foregroundColor(.secondary)
            } else {
                details
            }
        }
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
            (Text(Image(systemName: viewModel.task.state.iconSystemName)) + Text(" " + ConsoleFormatter.status(for: viewModel.task)))
                .font(ConsoleConstants.fontTitle)
                .fontWeight(.medium)
                .foregroundColor(viewModel.task.state.tintColor)
                .lineLimit(1)
            Spacer()
#if os(iOS) || os(macOS)
            PinView(viewModel: viewModel.pinViewModel, font: ConsoleConstants.fontTitle)
                .frame(width: 4, height: 4) // don't affect layout
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
        Text(ConsoleMessageCellViewModel.timeFormatter.string(from: viewModel.task.createdAt))
            .font(ConsoleConstants.fontTitle)
#if os(watchOS)
            .foregroundColor(.secondary)
#else
            .foregroundColor(viewModel.task.state == .failure ? .red : .secondary)
#endif
            .lineLimit(1)
            .backport.monospacedDigit()
    }

    private var message: some View {
        Text(viewModel.task.url ?? "–")
            .font(ConsoleConstants.fontBody)
            .foregroundColor(.primary)
            .lineLimit(ConsoleSettings.shared.lineLimit)
    }

    private var details: some View {
#if os(watchOS)
        HStack {
            Text(viewModel.task.httpMethod ?? "GET")
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
        Text(viewModel.task.httpMethod ?? "GET").font(ConsoleConstants.fontBody.smallCaps()) +
         Text("   ") +
        Text(Image(systemName: "arrow.up")).fontWeight(.light) +
        Text(" " + byteCount(for: viewModel.task.requestBodySize)) +
        Text("   ") +
        Text(Image(systemName: "arrow.down")).fontWeight(.light) +
        Text(" " + byteCount(for: viewModel.task.responseBodySize)) +
        Text("   ") +
        Text(Image(systemName: "clock")).fontWeight(.light) +
        Text(" " + (ConsoleFormatter.duration(for: viewModel.task) ?? "–"))
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
    }
}

private struct ConsoleTimeText: View {
    let date: Date
    let color: Color

    var body: some View {
        Text(ConsoleMessageCellViewModel.timeFormatter.string(from: date))
            .font(ConsoleConstants.fontTitle)
            .lineLimit(1)
            .backport.monospacedDigit()
    }
}

#if DEBUG
struct ConsoleTaskCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleTaskCell(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
