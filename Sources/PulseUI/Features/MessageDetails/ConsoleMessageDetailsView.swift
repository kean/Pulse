// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleMessageDetailsView: View {
    let message: LoggerMessageEntity

#if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: trailingNavigationBarItems)
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack {
            NavigationLink(destination: ConsoleMessageMetadataView(message: message)) {
                Image(systemName: "info.circle")
            }
            PinButton(viewModel: .init(message), isTextNeeded: false)
        }
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
#elseif os(macOS)
    @State private var isDetailsLinkActive = false

    var body: some View {
        ConsoleMessageMetadataView(message: message)
            .background(VStack {
                NavigationLink(isActive: $isDetailsLinkActive, destination: { RichTextView(viewModel: makeTextViewModel()) }, label: { EmptyView() })
            }.invisible())
            .onAppear { isDetailsLinkActive = true }
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
