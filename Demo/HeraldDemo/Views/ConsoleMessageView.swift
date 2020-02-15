// The MIT License (MIT)
//
// Copyright (c) 2020 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Herald

struct ConsoleMessageView: View {
    let model: ConsoleMessageViewModel
    @Environment(\.colorScheme) var colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.title)
                .font(.caption)
                .foregroundColor(model.style.titleColor)
            Text(model.text)
                .font(.body)
                .foregroundColor(model.style.textColor)
                .lineLimit(4)
        }.padding()
            .background(model.style.backgroundColor.opacity(colorScheme == .dark ? 0.1 : 0.05))
    }
}

struct ConsoleMessageViewModel {
    let title: String
    let text: String
    let style: ConsoleMessageStyle

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    init(title: String, text: String, style: ConsoleMessageStyle) {
        self.title = title
        self.text = text
        self.style = style
    }

    init(message: MessageEntity) {
        let time = ConsoleMessageViewModel.timeFormatter
            .string(from: message.created)
        let prefix = message.level.icon.map { $0 + " "} ?? ""
        let category = message.category == "default" ? "" : ":\(message.category)"
        self.title = "\(prefix)\(time) | \(message.system)\(category)"
        self.text = message.text
        self.style = ConsoleMessageStyle.make(level: message.level)
    }
}

extension Logger.Level {
    var icon: String? {
        switch self {
        case .debug: return nil
        case .info: return nil
        case .error: return "⚠️"
        case .fatal: return "🆘"
        }
    }
}

struct ConsoleMessageStyle {
    let titleColor: Color
    let textColor: Color
    let backgroundColor: Color

    static func make(level: Logger.Level) -> ConsoleMessageStyle {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .error: return .error
        case .fatal: return .fatal
        }
    }

    static let debug = ConsoleMessageStyle(
        titleColor: Color(.secondaryLabel),
        textColor: Color(.label),
        backgroundColor: Color(.systemBackground)
    )

    static let info = ConsoleMessageStyle(
        titleColor: Color(.label),
        textColor: Color(.label),
        backgroundColor: Color(.systemBlue)
    )

    static let error = ConsoleMessageStyle(
        titleColor: Color(.systemOrange),
        textColor: Color(.systemOrange),
        backgroundColor: Color(.systemOrange)
    )

    static let fatal = ConsoleMessageStyle(
        titleColor: Color(.systemRed),
        textColor: Color(.systemRed),
        backgroundColor: Color(.systemRed)
    )
}


struct ConsoleMessageView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .debug)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .info)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .error)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .fatal)
            ).previewLayout(.sizeThatFits)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .debug)
            ).previewDisplayName("Debug Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .info)
            ).previewDisplayName("Info Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .error)
            ).previewDisplayName("Error Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                ConsoleMessageViewModel(title: "Today 5:00 PM | application", text: "UIApplication.willEnterForeground", style: .fatal)
            ).previewDisplayName("Fatal Dark")
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)

            ConsoleMessageView(model:
                 ConsoleMessageViewModel(title: "Today 5:00 PM | application:networking", text: "Aenean vel ullamcorper ipsum. Pellentesque viverra fringilla accumsan. Vestibulum blandit accumsan tortor, viverra laoreet augue rutrum et. Praesent quis libero est. Duis imperdiet, eros sit amet commodo tincidunt, risus est interdum mi, sit amet sagittis nunc sapien et orci. Phasellus lectus ante, rutrum vel lorem vitae, interdum elementum erat. ", style: .debug)
             ).previewLayout(.sizeThatFits)
        }
    }
}
