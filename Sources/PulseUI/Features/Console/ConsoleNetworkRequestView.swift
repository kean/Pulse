// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine
import CoreData

#if os(watchOS) || os(tvOS)

struct ConsoleNetworkRequestView: View {
    let viewModel: ConsoleNetworkRequestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                title
                #if os(watchOS)
                Spacer()
                PinView(viewModel: viewModel.pinViewModel, font: fonts.title)
                #else
                PinView(viewModel: viewModel.pinViewModel, font: fonts.title)
                Spacer()
                #endif
            }
            text
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var title: some View {
        #if os(watchOS)
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline) {
                statusCircle
                Text(viewModel.status)
                    .font(fonts.title)
                    .foregroundColor(.secondary)
            }
            Text(viewModel.title)
                .font(fonts.title)
                .foregroundColor(.secondary)
        }
        #else
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            statusCircle
            Text(viewModel.status + " · " + viewModel.title)
                .font(fonts.title)
                .foregroundColor(.secondary)
        }
        #endif
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

    private var fonts: Fonts {
        #if os(watchOS)
        return Fonts(title: .system(size: 12), body: .system(size: 15))
        #elseif os(tvOS)
        return Fonts(title: .body, body: .body)
        #endif
    }

    private var circleSize: CGFloat {
        #if os(tvOS)
        return 20
        #else
        return 10
        #endif
    }
}

#endif
