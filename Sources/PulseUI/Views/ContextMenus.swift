// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS)

import SwiftUI
import Pulse
import Combine

enum ContextMenu {
    struct NetworkTaskContextMenuItems: View {
        let task: NetworkTaskEntity
#if os(iOS)
        @Binding private(set) var sharedItems: ShareItems?
#else
        @Binding private(set) var isSharing: Bool
#endif

        var body: some View {
            Section {
#if os(iOS)
                ContextMenu.NetworkTaskShareMenu(task: task, shareItems: $sharedItems)
#else
                Button(action: { isSharing = true }) {
                    Label("Share...", systemImage: "square.and.arrow.up")
                }
#endif
                ContextMenu.NetworkTaskCopyMenu(task: task)
            }
            if let message = task.message {
                PinButton(viewModel: .init(message))
            }
        }
    }

    struct NetworkTaskShareMenu: View {
        let task: NetworkTaskEntity
        @Binding var shareItems: ShareItems?

        var body: some View {
            Menu(content: content) {
                Label("Share...", systemImage: "square.and.arrow.up")
            }
        }

        @ViewBuilder
        private func content() -> some View {
            AttributedStringShareMenu(shareItems: $shareItems) {
                TextRenderer(options: .sharing).make {
                    $0.render(task, content: .sharing)
                }
            }
            Button(action: { shareItems = ShareItems([task.cURLDescription()]) }) {
                Label("Share as cURL", systemImage: "square.and.arrow.up")
            }
        }
    }

    struct NetworkTaskCopyMenu: View {
        let task: NetworkTaskEntity

        var body: some View {
            Menu(content: content) {
                Label("Copy...", systemImage: "doc.on.doc")
            }
        }

        @ViewBuilder
        private func content() -> some View {
            if let url = task.url {
                Button(action: {
                    UXPasteboard.general.string = url
                    runHapticFeedback()
                }) {
                    Label("Copy URL", systemImage: "doc.on.doc")
                }
            }
            if let host = task.host {
                Button(action: {
                    UXPasteboard.general.string = host
                    runHapticFeedback()
                }) {
                    Label("Copy Host", systemImage: "doc.on.doc")
                }
            }
            if task.requestBodySize > 0 {
                Button(action: {
                    guard let data = task.requestBody?.data else { return }
                    UXPasteboard.general.string = String(data: data, encoding: .utf8)
                    runHapticFeedback()
                }) {
                    Label("Copy Request", systemImage:"arrow.up.circle")
                }
            }
            if task.responseBodySize > 0 {
                Button(action: {
                    guard let data = task.responseBody?.data else { return }
                    UXPasteboard.general.string = String(data: data, encoding: .utf8)
                    runHapticFeedback()
                }) {
                    Label("Copy Response", systemImage: "arrow.down.circle")
                }
            }
        }
    }
}

struct StringSearchOptionsMenu: View {
    @Binding private(set) var options: StringSearchOptions
    var isKindNeeded = true

#if os(macOS)
    var body: some View {
        Menu(content: { contents }, label: {
            Image(systemName: "ellipsis.circle")
        })
        .opacity(0.5)
        .pickerStyle(.inline)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
#else
    var body: some View {
        contents
    }
#endif

    @ViewBuilder
    private var contents: some View {
        Picker("Kind", selection: $options.kind) {
            ForEach(StringSearchOptions.Kind.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        Picker("Case Sensitivity", selection: $options.caseSensitivity) {
            ForEach(StringSearchOptions.CaseSensitivity.allCases, id: \.self) {
                Text($0.rawValue).tag($0)
            }
        }
        if let rules = options.allEligibleMatchingRules(), isKindNeeded {
            Picker("Matching Rule", selection: $options.rule) {
                ForEach(rules, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
        }
    }
}

struct AttributedStringShareMenu: View {
    @Binding var shareItems: ShareItems?
    let string: () -> NSAttributedString

    var body: some View {
        Button(action: { shareItems = ShareService.share(string(), as: .plainText) }) {
            Label("Share as Text", systemImage: "square.and.arrow.up")
        }
        Button(action: { shareItems = ShareService.share(string(), as: .html) }) {
            Label("Share as HTML", systemImage: "square.and.arrow.up")
        }
#if os(iOS)
        Button(action: { shareItems = ShareService.share(string(), as: .pdf) }) {
            Label("Share as PDF", systemImage: "square.and.arrow.up")
        }
#endif
    }
}

#if DEBUG
struct StringSearchOptionsMenu_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 32) {
            Spacer()
            Menu(content: {
                AttributedStringShareMenu(shareItems: .constant(nil)) {
                    TextRenderer(options: .sharing).make { $0.render(LoggerStore.preview.entity(for: .login), content: .sharing) }
                }
            }) {
                Text("Attributed String Share")
            }
            Menu(content: {
                Section(header: Label("Search Options", systemImage: "magnifyingglass")) {
                    StringSearchOptionsMenu(options: .constant(.default))
                }
            }) {
                Text("Search Options")
            }
        }
    }
}
#endif

#endif
