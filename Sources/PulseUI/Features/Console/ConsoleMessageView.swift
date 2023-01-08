// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

#if os(watchOS) || os(tvOS) || os(macOS)

struct ConsoleMessageView: View {
    let viewModel: ConsoleMessageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.message.logLevel.name.uppercased())
                    .font(fontTitle)
                    .foregroundColor(.secondary)
                Spacer()
#if os(macOS)
            PinView(viewModel: viewModel.pinViewModel, font: fontTitle)
#endif
                let time = Text(viewModel.time)
                    .font(fontTitle)
                    .foregroundColor(.secondary)
                if #available(tvOS 15, watchOS 8, macOS 12, *) {
                    time.monospacedDigit()
                } else {
                    time
                }
            }
            Text(viewModel.message.text)
                .font(fontBody)
                .foregroundColor(.textColor(for: viewModel.message.logLevel))
                .lineLimit(ConsoleSettings.shared.lineLimit)
        }
    }

#if os(watchOS)
    private let fontTitle = Font.system(size: 14)
    private let fontBody = Font.system(size: 15)
#elseif os(macOS)
    private let fontTitle = Font.body
    private let fontBody = Font.body
#else
    private let fontTitle = Font.caption
    private let fontBody = Font.caption
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


#endif
