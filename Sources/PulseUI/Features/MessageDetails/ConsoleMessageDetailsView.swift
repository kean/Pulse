// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#if os(iOS) || os(tvOS) || os(macOS) || os(watchOS) || os(visionOS)

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
package struct ConsoleMessageDetailsView: View {
    package let message: LoggerMessageEntity

    package init(message: LoggerMessageEntity) {
        self.message = message
    }

#if os(iOS) || os(visionOS)
    package var body: some View {
        contents
            .inlineNavigationTitle("")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    trailingNavigationBarItems
                }
            }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        NavigationLink(destination: ConsoleMessageMetadataView(message: message)) {
            Image(systemName: "info.circle")
        }
    }
#elseif os(watchOS)
    package var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink(destination: ConsoleMessageMetadataView(message: message)) {
                    Label("Details", systemImage: "info.circle")
                }
                contents
            }
        }
    }
#elseif os(macOS)
    package var body: some View {
        contents
            .inlineNavigationTitle("")
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    NavigationLink(destination: ConsoleMessageMetadataView(message: message)) {
                        Image(systemName: "info.circle")
                    }
                }
            }
    }
#elseif os(tvOS)
    package var body: some View {
        contents
    }
#endif

    private var contents: some View {
        VStack {
            RichTextView(viewModel: makeTextViewModel())
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func makeTextViewModel() -> RichTextViewModel {
        RichTextViewModel(string: TextRenderer().preformatted(message.text))
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    NavigationView {
        ConsoleMessageDetailsView(message: makeMockMessage())
    }
}
#endif

#endif

#if DEBUG

package func makeMockMessage() -> LoggerMessageEntity {
    let entity = LoggerMessageEntity(context: LoggerStore.mock.viewContext)
    entity.text = "test"
    entity.createdAt = Date()
    entity.label = "auth"
    entity.level = LoggerStore.Level.critical.rawValue
    entity.file = "LoggerStore.swift"
    entity.function = "createMockMessage()"
    entity.line = 12
    entity.rawMetadata = "customKey: customValue"
    return entity
}

#endif
