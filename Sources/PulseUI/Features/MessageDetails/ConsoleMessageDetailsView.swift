// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct ConsoleMessageDetailsView: View {
    let viewModel: ConsoleMessageDetailsViewModel

#if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: trailingNavigationBarItems)
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: ConsoleMessageMetadataView(message: viewModel.message)) {
                Image(systemName: "info.circle")
            }
            PinButton(viewModel: viewModel.pin, isTextNeeded: false)
        }
    }
#elseif os(watchOS)
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink(destination: ConsoleMessageMetadataView(message: viewModel.message)) {
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
        ConsoleMessageMetadataView(message: viewModel.message)
            .background(InvisibleNavigationLinks {
                NavigationLink.programmatic(isActive: $isDetailsLinkActive) {
                    _MessageTextView(viewModel: viewModel)
                }
            }
            )
            .onAppear { isDetailsLinkActive = true }
    }
#endif

    private var contents: some View {
        VStack {
            textView
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var textView: some View {
        RichTextView(viewModel: viewModel.textViewModel)
    }

#if os(watchOS) || os(tvOS)
    private var tags: some View {
        VStack(alignment: .leading) {
            ForEach(viewModel.tags, id: \.title) { tag in
                HStack {
                    Text(tag.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tag.value)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8)
    }
#endif
}

#if os(macOS)

private struct _MessageTextView: View {
    let viewModel: ConsoleMessageDetailsViewModel
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var isShowingShareSheet = false

    var body: some View {
        RichTextView(viewModel: viewModel.textViewModel)
    }
}
#endif

#if DEBUG
struct ConsoleMessageDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleMessageDetailsView(viewModel: .init(message: makeMockMessage()))
        }
    }
}

func makeMockMessage() -> LoggerMessageEntity {
    let entity = LoggerMessageEntity(context: LoggerStore.mock.viewContext)
    entity.text = "test"
    entity.createdAt = Date()

    let label = LoggerLabelEntity(context: LoggerStore.mock.viewContext)
    label.name = "auth"
    entity.label = label

    entity.level = LoggerStore.Level.critical.rawValue
    entity.session = UUID()
    entity.file = "LoggerStore.swift"
    entity.function = "createMockMessage()"
    entity.line = 12
    entity.rawMetadata = "customKey: customValue"
    return entity
}
#endif
