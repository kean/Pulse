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
    @State private var shareItems: ShareItems?

    var entities: CurrentValueSubject<[LoggerMessageEntity], Never>
    var options: ConsoleTextRenderer.Options = .init()
    var onClose: (() -> Void)?

    var body: some View {
        textView
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.display(entities, options) }
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
            .sheet(item: $shareItems, content: ShareView.init)
    }

    private var textView: some View {
        RichTextView(
            viewModel: viewModel.text,
            isAutomaticLinkDetectionEnabled: options.isLinkDetectionEnabled,
            isPrincipalSearchBarPlacement: true
        )
    }

    @ViewBuilder
    private var menu: some View {
        Section {
            Button(action: { shareItems = ShareItems([viewModel.text.text.string]) }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(action: { viewModel.display(entities, options) }) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }.disabled(viewModel.isButtonRefreshHidden)
//            // Unfortunately, this isn't working properly in UITextView (use WebView!)
//            Button(action: viewModel.text.scrollToBottom) {
//                Label("Scroll to Bottom", systemImage: "arrow.down")
//            }
        }
    }
}

@available(iOS 14.0, *)
final class ConsoleTextViewModel: ObservableObject {
    private var messages: CurrentValueSubject<[LoggerMessageEntity], Never> = .init([])
    private var renderer = ConsoleTextRenderer()
    private var cancellables: [AnyCancellable] = []
    private var entitiesObserver: AnyCancellable?

    let text: RichTextViewModel
    @Published private(set) var isButtonRefreshHidden = true
    private var lastTimeRefreshHidden = Date().addingTimeInterval(-3)

    init() {
        self.text = RichTextViewModel(string: "")
    }

    func display(_ entities: CurrentValueSubject<[LoggerMessageEntity], Never>, _ options: ConsoleTextRenderer.Options) {
        self.renderer = ConsoleTextRenderer(options: options)
        let string = renderer.render(entities.value.reversed())
        self.text.display(string)

        self.hideRefreshButton()
        self.entitiesObserver = entities.dropFirst().sink { [weak self] _ in
            self?.showRefreshButtonIfNeeded()
        }
    }

    private func hideRefreshButton() {
        guard !isButtonRefreshHidden else { return }
        isButtonRefreshHidden = true
    }

    private func showRefreshButtonIfNeeded() {
        guard isButtonRefreshHidden else { return }
        isButtonRefreshHidden = false
    }
}

#if DEBUG
@available(iOS 14.0, *)
struct ConsoleTextView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                ConsoleTextView(entities: entities) { _ in
                    return // Use default settings
                }
            }
            .previewDisplayName("Default")

            NavigationView {
                ConsoleTextView(entities: entities) {
                    $0.isMonocrhome = false
                    $0.isBodySyntaxHighlightingEnabled = true
                    $0.networkContent = .all
                }
            }
            .previewDisplayName("Color")

            NavigationView {
                ConsoleTextView(entities: entities) {
                    $0.isMonocrhome = true
                    $0.isBodySyntaxHighlightingEnabled = false
                    $0.networkContent = .all
                }
            }
            .previewDisplayName("Monochrome")

            NavigationView {
                ConsoleTextView(entities: entities) {
                    $0.networkContent = .all
                    $0.isBodyExpanded = true
                }
            }
            .previewDisplayName("Netwok Expanded")
        }
    }
}

private let entities = try! LoggerStore.mock.allMessages()

@available(iOS 14.0, tvOS 14.0, *)
private extension ConsoleTextView {
    init(entities: [LoggerMessageEntity], _ configure: (inout ConsoleTextRenderer.Options) -> Void) {
        var options = ConsoleTextRenderer.Options()
        configure(&options)
        self.init(entities: .init(entities.reversed()), options: options, onClose: {})
    }
}

#endif

#endif
