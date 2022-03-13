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

    // TODO: remove
    // I tried moving this to a ViewModel, but it started crashing
    @State private var isPinned = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                title
                #if os(watchOS)
                Spacer()
                if isPinned { pin }
                #else
                if isPinned { pin }
                Spacer()
                #endif
            }
            text
        }
        .padding(.vertical, 4)
        .onReceive(model.isPinnedPublisher) { isPinned = $0 }
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

    private var pin: some View {
        Image(systemName: "pin")
            .font(fonts.title)
            .foregroundColor(.secondary)
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

#endif
