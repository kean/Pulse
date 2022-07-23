// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseCore

struct ConsoleMessageDetailsView: View {
    let viewModel: ConsoleMessageDetailsViewModel
    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @State private var isShowingShareSheet = false
    var onClose: (() -> Void)?

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
        HStack {
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
            VStack {
                HStack {
                    PinButton3(viewModel: viewModel.pin)
                    NavigationLink(destination: ConsoleMessageMetadataView(message: viewModel.message)) {
                        VStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Details")
                                .font(.caption2)
                        }.frame(height: 42)
                    }
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
    @State var isMetaVisible = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: { isMetaVisible = true }) {
                    Image(systemName: "info.circle")
                }.padding(.leading, 4)
                if let badge = viewModel.badge {
                    BadgeView(viewModel: BadgeViewModel(title: badge.title, color: badge.color.opacity(colorScheme == .light ? 0.25 : 0.5)))
                }
                Spacer()
                if let onClose = onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            .padding([.leading, .trailing], 6)
            .frame(height: 27, alignment: .center)
            Divider()
            textView
                .background(colorScheme == .dark ? Color(NSColor(red: 30/255.0, green: 30/255.0, blue: 30/255.0, alpha: 1)) : .clear)
        }
        .sheet(isPresented: $isMetaVisible, content: {
            VStack(spacing: 0) {
                HStack {
                    Text("Message Details")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Close") { isMetaVisible = false }
                        .keyboardShortcut(.cancelAction)
                }.padding()
                ConsoleMessageMetadataView(message: viewModel.message)
            }.frame(width: 440, height: 600)
        })
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

#if DEBUG
struct ConsoleMessageDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleMessageDetailsView(viewModel: .init(store: LoggerStore.mock, message: makeMockMessage()), onClose: {})
            }
        }
    }
}

func makeMockMessage() -> LoggerMessageEntity {
    let entity = LoggerMessageEntity(context: LoggerStore.mock.container.viewContext)
    entity.text = "test"
    entity.createdAt = Date()
    entity.label = "auth"
    entity.level = "critical"
    entity.session = UUID().uuidString
    entity.file = "~/Develop/Pulse/LoggerStore.swift"
    entity.filename = "LoggerStore.swift"
    entity.function = "createMockMessage()"
    entity.line = 12

    let meta = LoggerMetadataEntity(context: LoggerStore.mock.container.viewContext)
    meta.key = "customKey"
    meta.value = "customValue"

    entity.metadata = Set([meta])
    return entity
}
#endif
