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

    init(viewModel: ConsoleTaskCellViewModel) {
        self.viewModel = viewModel
        self.progressViewModel = viewModel.progress
    }

    var body: some View {
        let contents = VStack(alignment: .leading, spacing: 5) {
            title
            message
#if os(iOS) || os(macOS)
            if viewModel.task.state == .pending {
                Text(ConsoleFormatter.progress(for: viewModel.task) ?? "...")
                    .lineLimit(1)
                    .font(ConsoleConstants.fontTitle)
                    .foregroundColor(.secondary)
            } else {
                details
            }
#endif
        }
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
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
            Text(viewModel.time)
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(viewModel.task.state == .failure ? .red : .secondary)
                .lineLimit(1)
                .backport.monospacedDigit()
        }
    }

    private var message: some View {
        (Text((viewModel.task.httpMethod ?? "GET") + " ").font(ConsoleConstants.fontBody.smallCaps()).fontWeight(.medium) +
         Text(viewModel.task.url ?? "–"))
        .font(ConsoleConstants.fontBody)
        .foregroundColor(.primary)
        .lineLimit(ConsoleSettings.shared.lineLimit)
    }

    private var details: some View {
        (Text(Image(systemName: "arrow.up.circle")).fontWeight(.light) +
         Text(" " + byteCount(for: viewModel.task.requestBodySize)) +
         Text("   ") +
         Text(Image(systemName: "arrow.down.circle")).fontWeight(.light) +
         Text(" " + byteCount(for: viewModel.task.responseBodySize)) +
         Text("   ") +
         Text(Image(systemName: "clock")).fontWeight(.light) +
         Text(" " + (ConsoleFormatter.duration(for: viewModel.task) ?? "–")))
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
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
