// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if !PULSE_STANDALONE_APP

import SwiftUI
import Pulse

@available(iOS 15, *)
struct ConsoleMessageDetailsView: View {
    let message: LoggerMessageEntity

#if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
#elseif os(macOS)
    @State private var selectedTab: ConsoleMessageTab = .message

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
            ButtonCloseDetailsView()
        }
        .padding(.horizontal, 10)
        .offset(y: -2)
        .frame(height: 27, alignment: .center)
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
        let viewModel = RichTextViewModel(string: TextRenderer().preformatted(message.text))
        viewModel.isFilterEnabled = true
        return viewModel
    }
}

#if DEBUG
@available(iOS 15, *)
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

#endif
