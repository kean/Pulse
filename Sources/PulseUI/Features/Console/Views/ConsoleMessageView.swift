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
                    .lineLimit(1)
                    .font(ConsoleConstants.fontTitle)
                    .foregroundColor(.secondary)
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
            Text(viewModel.preprocessedText)
                .font(ConsoleConstants.fontBody)
                .foregroundColor(.textColor(for: viewModel.message.logLevel))
                .lineLimit(ConsoleSettings.shared.lineLimit)
        }
#if os(macOS)
        .padding(.vertical, 3)
#endif
    }
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

struct ConsoleConstants {
#if os(watchOS)
    static let fontTitle = Font.system(size: 14)
    static let fontBody = Font.system(size: 15)
#elseif os(macOS)
    static let fontTitle = Font.caption
    static let fontBody = Font.body
#else
    static let fontTitle = Font.caption
    static let fontBody = Font.caption
#endif
}

#endif
