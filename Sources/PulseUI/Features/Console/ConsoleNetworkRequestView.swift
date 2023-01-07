// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine
import CoreData

struct ConsoleNetworkRequestView: View {
    @ObservedObject var viewModel: ConsoleNetworkRequestViewModel
    @ObservedObject var progressViewModel: ProgressViewModel

    init(viewModel: ConsoleNetworkRequestViewModel) {
        self.viewModel = viewModel
        self.progressViewModel = viewModel.progress
    }

#if os(watchOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title
            Text(viewModel.task.url ?? "–")
                .font(.system(size: 15))
                .lineLimit(ConsoleSettings.shared.lineLimit)
            Text(ConsoleFormatter.details(for: viewModel.task))
                .lineLimit(2)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
    }

    private var title: some View {
        HStack {
            HStack {
                Circle()
                    .frame(width: 10, height: 10)
                    .foregroundColor(viewModel.badgeColor)
                Text(viewModel.task.httpMethod ?? "GET")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
            let time = Text(viewModel.time)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            if #available(watchOS 8, *) {
                time.monospacedDigit()
            } else {
                time
            }
        }
    }
#else
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                header
#if os(macOS)
                PinView(viewModel: viewModel.pinViewModel, font: fonts.title)
                Spacer()
#endif
            }
            text.lineLimit(4)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var header: some View {
        title
    }

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing) {
            statusCircle
            Text(viewModel.fullTitle)
                .lineLimit(1)
                .font(fonts.title)
                .foregroundColor(.secondary)
        }
    }

    private var statusCircle: some View {
        Circle()
            .frame(width: circleSize, height: circleSize)
            .foregroundColor(viewModel.badgeColor)
    }

    private var text: some View {
        Text(viewModel.text)
            .font(fonts.body)
            .foregroundColor(.primary)
            .lineLimit(4)
    }

    private struct Fonts {
        let title: Font
        let body: Font
    }

#if os(iOS)
    private let spacing: CGFloat = 8
    private let fonts = Fonts(title: .caption, body: .body)
#else
    private let spacing: CGFloat = 8
    private let fonts = Fonts(title: .body, body: .body)
#endif

#if os(tvOS)
    private let circleSize: CGFloat = 20
#else
    private let circleSize: CGFloat = 10
#endif
#endif
}

#if DEBUG
struct ConsoleNetworkRequestView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleNetworkRequestView(viewModel: .init(task: LoggerStore.preview.entity(for: .login)))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif
