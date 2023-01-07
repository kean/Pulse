// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

#warning("TODO: macOS reimplement")
#warning("TODO: move toolbar items to the proper sections")

struct ConsoleMessageDetailsView: View {
    let viewModel: ConsoleMessageDetailsViewModel
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var isShowingShareSheet = false

    #if os(iOS)
    var body: some View {
        contents
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: trailingNavigationBarItems)
            .sheet(isPresented: $isShowingShareSheet) {
                ShareView(activityItems: [self.viewModel.prepareForSharing()])
            }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        HStack(spacing: 10) {
            if let badge = viewModel.badge {
                BadgeView(viewModel: BadgeViewModel(title: badge.title, color: badge.color.opacity(colorScheme == .light ? 0.25 : 0.5)))
            }
            NavigationLink(destination: ConsoleMessageMetadataView(message: viewModel.message)) {
                Image(systemName: "info.circle")
            }
            PinButton(viewModel: viewModel.pin, isTextNeeded: false)
            ShareButton {
                self.isShowingShareSheet = true
            }
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
            if let badge = viewModel.badge {
                BadgeView(viewModel: BadgeViewModel(title: badge.title, color: badge.color.opacity(colorScheme == .light ? 0.25 : 0.5)))
            }
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

#warning("TODO: reimplemmet this")

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
