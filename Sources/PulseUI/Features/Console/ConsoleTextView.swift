// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

@available(iOS 14.0, tvOS 14.0, *)
struct ConsoleTextView: View {
    @StateObject private var viewModel = ConsoleTextViewModel()

    var entities: () -> [LoggerMessageEntity]
    var options: ConsoleTextRenderer.Options = .init()
    var onClose: (() -> Void)?

    var body: some View {
        textView
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.display(entities(), options) }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu(content: { menu }) {
                            Image(systemName: "ellipsis.circle")
                        }
                        if let onClose = onClose {
                            Button(action: onClose) {
                                Image(systemName: "xmark")
                            }
                        }
                    }
                }
            }
    }

    private var textView: some View {
        RichTextView(
            viewModel: viewModel.text,
            isAutomaticLinkDetectionEnabled: options.isLinkDetectionEnabled,
            isPrincipalSearchBarPlacement: true
        )
        .id(ObjectIdentifier(viewModel.text)) // TODO: fix this, should not be required
    }

    @ViewBuilder
    private var menu: some View {
        Button(action: { viewModel.display(entities(), options) }) {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
    }
}

@available(iOS 14.0, *)
final class ConsoleTextViewModel: ObservableObject {
    private var messages: [LoggerMessageEntity] = []
    private var renderer = ConsoleTextRenderer()

    @Published private(set) var text: RichTextViewModel

    init() {
        self.text = RichTextViewModel(string: "")
    }

    func display(_ entities: [LoggerMessageEntity], _ options: ConsoleTextRenderer.Options) {
        self.renderer = ConsoleTextRenderer(options: options)
        self.text = RichTextViewModel(string: renderer.render(entities))
    }
}

#if DEBUG
@available(iOS 14.0, *)
struct ConsoleTextView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleTextView(entities: entitites) { _ in
                    return // Use default settings
                }
            }
            .previewDisplayName("Default")

            NavigationView {
                ConsoleTextView(entities: entitites) {
                    $0.isMonocrhome = false
                    $0.isBodySyntaxHighlightingEnabled = true
                    $0.networkContent = .all
                }
            }
            .previewDisplayName("Color")

            NavigationView {
                ConsoleTextView(entities: entitites) {
                    $0.isMonocrhome = true
                    $0.isBodySyntaxHighlightingEnabled = false
                    $0.isLinkDetectionEnabled = false
                    $0.networkContent = .all
                }
            }
            .previewDisplayName("Monochrome")

            NavigationView {
                ConsoleTextView(entities: entitites) {
                    $0.networkContent = .all
                }
            }
            .previewDisplayName("Netwok Expanded")
        }
    }
}

private let entitites = try! LoggerStore.mock.allMessages()

@available(iOS 14.0, tvOS 14.0, *)
private extension ConsoleTextView {
    init(entities: [LoggerMessageEntity], _ configure: (inout ConsoleTextRenderer.Options) -> Void) {
        var options = ConsoleTextRenderer.Options()
        configure(&options)
        self.init(entities: { entities }, options: options, onClose: {})
    }
}

#endif

#endif
