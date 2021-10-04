// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore
import CoreData
import Combine

#if os(iOS) || os(watchOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleMessageView: View {
    let model: ConsoleMessageViewModel

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
    
    private var title: some View {
        badge + Text(model.title)
            .font(fonts.title)
            .foregroundColor(.secondary)
    }

    private var badge: Text {
        guard let badge = model.badge else {
            return Text("")
        }
        var separator: Text {
            #if os(watchOS)
            return Text("\n")
            #else
            return Text(" · ")
                .font(fonts.title)
                .foregroundColor(.secondary)
            #endif
        }
        return Text(badge.title)
            .font(fonts.title)
            .foregroundColor(badge.color)
            + separator
    }

    private var pin: some View {
        Image(systemName: "pin")
            .font(fonts.title)
            .foregroundColor(.secondary)
    }

    private var text: some View {
        Text(model.text)
            .font(fonts.body)
            .foregroundColor(model.textColor)
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
}

#endif
