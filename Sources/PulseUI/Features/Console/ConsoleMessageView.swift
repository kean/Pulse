// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import CoreData
import Combine

struct ConsoleMessageView: View {
    let viewModel: ConsoleMessageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                title
#if os(macOS)
                PinView(viewModel: viewModel.pinViewModel, font: fonts.title)
                Spacer()
#endif
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
#if os(watchOS)
            return Text("\n")
#else
            return Text(" · ")
                .font(fonts.title)
                .foregroundColor(.secondary)
#endif
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
    
#if os(watchOS)
    private let fonts = Fonts(title: .system(size: 12), body: .system(size: 15))
#else
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

