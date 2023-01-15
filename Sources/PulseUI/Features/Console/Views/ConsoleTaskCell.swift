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

#if os(watchOS) || os(iOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
            Text(viewModel.task.url ?? "–")
                .font(ConsoleConstants.fontBody)
                .lineLimit(ConsoleSettings.shared.lineLimit)
            Text(ConsoleFormatter.details(for: viewModel.task))
                .lineLimit(2)
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
        }
    }

    private var title: some View {
        HStack {
            HStack {
                Circle()
                    .frame(width: 10, height: 10)
#if os(iOS)
                    .foregroundColor(Color(viewModel.badgeColor))
#else
                    .foregroundColor(viewModel.badgeColor)
#endif
                Text(viewModel.task.httpMethod ?? "GET")
                    .font(ConsoleConstants.fontTitle)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(viewModel.time)
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
                .backport.monospacedDigit()
        }
    }
#elseif os(tvOS) || os(macOS)
    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) {
            title
            Text(viewModel.task.url ?? "–")
                .font(ConsoleConstants.fontBody)
                .lineLimit(ConsoleSettings.shared.lineLimit)
        }
#if os(macOS)
        .padding(.vertical, 3)
#endif
    }

    private var title: some View {
        HStack {
            HStack(spacing: spacing) {
                Circle()
                    .frame(width: circleSize, height: circleSize)
                    .foregroundColor(viewModel.badgeColor)
                Text(ConsoleFormatter.subheadline(for: viewModel.task, hasTime: false))
                    .lineLimit(1)
                    .font(ConsoleConstants.fontTitle)
                    .foregroundColor(.secondary)
            }
            Spacer()
#if os(macOS)
            PinView(viewModel: viewModel.pinViewModel, font: ConsoleConstants.fontTitle)
#endif
            Text(viewModel.time)
                .lineLimit(1)
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.secondary)
                .backport.monospacedDigit()
        }
    }

#if os(macOS)
    private let verticalSpacing: CGFloat = 2
    private let spacing: CGFloat = 7
    private let circleSize: CGFloat = 8
#else
    private let verticalSpacing: CGFloat = 4
    private let spacing: CGFloat = 16
    private let circleSize: CGFloat = 20
#endif

#endif
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