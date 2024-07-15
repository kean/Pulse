// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

@available(iOS 15, visionOS 1.0, *)
struct ConsoleMessageDetailsView: View {
    let message: LoggerMessageEntity

#if os(iOS) || os(visionOS) || os(macOS)
    var body: some View {
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
        PinButton(viewModel: .init(message), isTextNeeded: false)
    }
#elseif os(watchOS)
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink(destination: ConsoleMessageMetadataView(message: message)) {
                    Label("Details", systemImage: "info.circle")
                }
                contents
            }
        }
    }
#elseif os(tvOS)
    var body: some View {
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
@available(iOS 15, visionOS 1.0, *)
struct ConsoleMessageDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleMessageDetailsView(message: makeMockMessage())
        }
    }
}

func makeMockMessage() -> LoggerMessageEntity {
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
