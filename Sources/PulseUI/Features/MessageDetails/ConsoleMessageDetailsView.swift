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
    @State private var selectedTab: ConsoleMessageTab = .message
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            selectedTabView
        }
    }

    private var toolbar: some View {
        HStack {
            InlineTabBar(items: ConsoleMessageTab.allCases, selection: $selectedTab)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
            }.buttonStyle(.plain)
        }.padding(EdgeInsets(top: 4, leading: 10, bottom: 5, trailing: 8))
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .message:
            RichTextView(viewModel: makeTextViewModel())
        case .metadata:
            ConsoleMessageMetadataView(message: message)
        }
    }

    private enum ConsoleMessageTab: String, Identifiable, CaseIterable, CustomStringConvertible {
        case message = "Messages"
        case metadata = "Metadata"

        var id: ConsoleMessageTab { self }
        var description: String { self.rawValue }
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
#if os(macOS)
            ConsoleMessageDetailsView(message: makeMockMessage(), onClose: {})
#else
            ConsoleMessageDetailsView(message: makeMockMessage())
#endif
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
