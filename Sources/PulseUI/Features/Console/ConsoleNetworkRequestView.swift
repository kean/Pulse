// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                header
                #if os(macOS)
                PinView(viewModel: viewModel.pinViewModel, font: fonts.title)
                Spacer()
                #endif
            }
            text
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var header: some View {
        #if os(watchOS)
        VStack(alignment: .leading, spacing: 1) {
            title
            Text(viewModel.time)
                .font(fonts.title)
                .foregroundColor(.secondary)
        }
        #else
        title
        #endif
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

#if os(watchOS)
    private let spacing: CGFloat = 4
    private let fonts = Fonts(title: .system(size: 12), body: .system(size: 15))
#elseif os(iOS)
    private let spacing: CGFloat = 8
    private let fonts = Fonts(title: .caption, body: .body)
#else
    private let spacing: CGFloat = 8
    private let fonts = Fonts(title: .body, body: .body)
#endif

#if os(watchOS)
    private let circleSize: CGFloat = 8
#elseif os(tvOS)
    private let circleSize: CGFloat = 20
#else
    private let circleSize: CGFloat = 10
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
