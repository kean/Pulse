// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

struct ConsoleMessageCell: View {
    let viewModel: ConsoleMessageCellViewModel
    var isDisclosureNeeded = false

    var body: some View {
        let contents = VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(viewModel.message.logLevel.name.uppercased())
                    .lineLimit(1)
                    .font(ConsoleConstants.fontTitle.weight(.medium))
                    .foregroundColor(titleColor)
                Spacer()
#if os(macOS) || os(iOS)
                PinView(message: viewModel.message)
#endif
                HStack(spacing: 3) {
                    Text(viewModel.time)
                        .lineLimit(1)
                        .font(ConsoleConstants.fontTitle)
                        .foregroundColor(titleColor)
                        .backport.monospacedDigit()
                    if isDisclosureNeeded {
                        ListDisclosureIndicator()
                    }
                }
            }
            Text(viewModel.preprocessedText)
                .font(ConsoleConstants.fontBody)
                .foregroundColor(.textColor(for: viewModel.message.logLevel))
                .lineLimit(ConsoleSettings.shared.lineLimit)
        }
#if os(macOS)
        .padding(.vertical, 3)
#endif
        if #unavailable(iOS 16) {
            contents.padding(.vertical, 4)
        } else {
            contents
        }
    }

    var titleColor: Color {
        viewModel.message.logLevel >= .warning ? .textColor(for: viewModel.message.logLevel) : .secondary
    }
}

struct ListDisclosureIndicator: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(.separator)
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
            .padding(.trailing, -12)
    }
}

#if DEBUG
struct ConsoleMessageCell_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleMessageCell(viewModel: .init(message: (try!  LoggerStore.mock.allMessages())[0]))
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
#elseif os(iOS)
    static let fontTitle = Font(TextHelper().font(style: .init(role: .subheadline, style: .monospacedDigital)))
    static let fontBody = Font(TextHelper().font(style: .init(role: .body2)))
#else
    static let fontTitle = Font.caption
    static let fontBody = Font.caption
#endif
}
