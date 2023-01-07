// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleMessageMetadataView: View {
    let message: LoggerMessageEntity

    var body: some View {
        RichTextView(viewModel: .init(string: string))
            .backport.navigationTitle("Message Details")
    }

    private var string: NSAttributedString {
        let renderer = TextRenderer()
        let strings = sections.map { renderer.render($0) }
        return renderer.joined(strings)
    }

    private var sections: [KeyValueSectionViewModel] {
        return [
            KeyValueSectionViewModel(title: "Summary", color: message.tintColor, items: [
                ("Date", dateFormatter.string(from: message.createdAt)),
                ("Level", LoggerStore.Level(rawValue: message.level)?.name),
                ("Label", message.label.name.nonEmpty)
            ]),
            KeyValueSectionViewModel(title: "Details", color: .primary, items: [
                ("Session", message.session.uuidString.nonEmpty),
                ("File", message.file.nonEmpty),
                ("Function", message.function.nonEmpty),
                ("Line", message.line == 0 ? nil : "\(message.line)"),
            ]),
            KeyValueSectionViewModel(title: "Metadata", color: .indigo, items: metadataItems)
        ]
    }

    private var metadataItems: [(String, String?)] {
        message.metadata.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value )}
    }
}

private extension LoggerMessageEntity {
    var tintColor: Color {
        Color.badgeColor(for: .init(rawValue: level) ?? .debug)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US")
    formatter.dateFormat = "HH:mm:ss.SSS, yyyy-MM-dd"
    return formatter
}()

#if DEBUG
struct ConsoleMessageMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleMessageMetadataView(message: makeMockMessage())
        }
    }
}
#endif
