// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import Combine
import CoreData

#if os(iOS) || os(watchOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleNetworkRequestView: View {
    let model: ConsoleNetworkRequestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                title
                #if os(watchOS)
                Spacer()
                model.pinViewModel.map { PinView(viewModel: $0, font: fonts.title) }
                #else
                model.pinViewModel.map { PinView(viewModel: $0, font: fonts.title) }
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
                Text(model.status)
                    .font(fonts.title)
                    .foregroundColor(.secondary)
            }
            Text(model.title)
                .font(fonts.title)
                .foregroundColor(.secondary)
        }
        #else
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            statusCircle
            Text(model.status + " · " + model.title)
                .font(fonts.title)
                .foregroundColor(.secondary)
        }
        #endif
    }

    private var statusCircle: some View {
        Circle()
            .frame(width: circleSize, height: circleSize)
            .foregroundColor(model.badgeColor)
    }

    private var text: some View {
        Text(model.text)
            .font(fonts.body)
            .foregroundColor(.primary)
            .lineLimit(4)
    }

    private struct Fonts {
        let title: Font
        let body: Font
    }

    private var fonts: Fonts {
        #if os(iOS)
        return Fonts(title: .caption, body: .system(size: 15))
        #elseif os(watchOS)
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

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
private struct PinView: View {
    @ObservedObject var viewModel: PinButtonViewModel
    let font: Font

    var body: some View {
        if viewModel.isPinned {
            Image(systemName: "pin")
                .font(font)
                .foregroundColor(.secondary)
        }
    }
}

#endif
