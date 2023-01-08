// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

struct ConsoleMessageView: View {
    let viewModel: ConsoleMessageViewModel

#if os(watchOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.message.logLevel.name.uppercased())
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Spacer()
                let time = Text(viewModel.time)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                if #available(tvOS 15, watchOS 8, *) {
                    time.monospacedDigit()
                } else {
                    time
                }
            }
            Text(viewModel.message.text)
                .font(.system(size: 15))
                .foregroundColor(.textColor(for: viewModel.message.logLevel))
                .lineLimit(ConsoleSettings.shared.lineLimit)
        }
    }
#elseif os(tvOS)
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                let time = Text(ConsoleFormatter.subheadline(for: viewModel.message))
                    .font(.caption)
                    .foregroundColor(.secondary)
                if #available(tvOS 15, watchOS 8, *) {
                    time.monospacedDigit()
                } else {
                    time
                }
                Spacer()

            }
            Text(viewModel.message.text)
                .font(.caption)
                .foregroundColor(.textColor(for: viewModel.message.logLevel))
                .lineLimit(ConsoleSettings.shared.lineLimit)
        }
    }
#else
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                title
                PinView(viewModel: viewModel.pinViewModel, font: fonts.title)
                Spacer()
            }
            text.lineLimit(4)
        }
        .padding(.vertical, 4)
    }

    private var title: some View {
        badge + (Text(viewModel.title)
            .foregroundColor(.secondary)
            .font(fonts.title))
    }

#warning("TODO: simplify this on tvos")
    private var badge: Text {
        var separator: Text {
            return Text(" · ")
                .font(fonts.title)
                .foregroundColor(.secondary)
        }
        return Text(viewModel.level)
            .font(fonts.title)
            .foregroundColor(.secondary)
        + separator
    }

    private var pin: some View {
        Image(systemName: "pin")
            .font(fonts.title)
            .foregroundColor(.secondary)
    }

    private var text: some View {
        Text(viewModel.text)
            .font(fonts.body)
            .foregroundColor(viewModel.textColor)
    }

    private struct Fonts {
        let title: Font
        let body: Font
    }

    private let fonts = Fonts(title: .body, body: .body)
#endif
}

#if DEBUG
struct ConsoleMessageView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleMessageView(viewModel: .init(message: (try!  LoggerStore.mock.allMessages())[0]))
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

