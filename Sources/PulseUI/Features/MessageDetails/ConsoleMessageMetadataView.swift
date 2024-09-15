// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 16, macOS 13, visionOS 1, *)
struct ConsoleMessageMetadataView: View {
    let message: LoggerMessageEntity

    init(message: LoggerMessageEntity) {
        self.message = message
    }

    var body: some View {
        RichTextView(viewModel: .init(string: string))
            .navigationTitle("Message Details")
    }

    private var string: NSAttributedString {
        let renderer = TextRenderer()
        let sections = KeyValueSectionViewModel.makeMetadata(for: message)
        renderer.render(sections)
        return renderer.make()
    }
}

extension KeyValueSectionViewModel {
    package static func makeMetadata(for message: LoggerMessageEntity) -> [KeyValueSectionViewModel] {
        let metadataItems: [(String, String?)] = message.metadata
            .sorted(by: { $0.key < $1.key })
            .map { ($0.key, $0.value )}
        return [
            KeyValueSectionViewModel(title: "Summary", color: .textColor(for: message.logLevel), items: [
                ("Date", DateFormatter.fullDateFormatter.string(from: message.createdAt)),
                ("Level", LoggerStore.Level(rawValue: message.level)?.name),
                ("Label", message.label.nonEmpty)
            ]),
            KeyValueSectionViewModel(title: "Details", color: .primary, items: [
                ("File", message.file.nonEmpty),
                ("Function", message.function.nonEmpty),
                ("Line", message.line == 0 ? nil : "\(message.line)")
            ]),
            KeyValueSectionViewModel(title: "Metadata", color: .indigo, items: metadataItems)
        ]
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

#if DEBUG
@available(iOS 16, macOS 13, visionOS 1, *)
struct ConsoleMessageMetadataView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleMessageMetadataView(message: makeMockMessage())
        }
    }
}
#endif
