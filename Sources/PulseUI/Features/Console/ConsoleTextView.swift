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
            .onAppear {
                viewModel.setOptions(options)
                viewModel.bind(entities)
            }
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
            Button(action: viewModel.refresh) {
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
    private var entities: CurrentValueSubject<[LoggerMessageEntity], Never> = .init([])
    private let renderer = ConsoleTextRenderer()

    private var cancellables: [AnyCancellable] = []

    let text: RichTextViewModel
    @Published private(set) var isButtonRefreshHidden = true
    private var lastTimeRefreshHidden = Date().addingTimeInterval(-3)

    init() {
        self.text = RichTextViewModel(string: "")
        self.text.onLinkTapped = { [unowned self] in onLinkTapped($0) }
    }

    func setOptions(_ options: ConsoleTextRenderer.Options) {
        self.renderer.setOptions(options)
    }

    func bind(_ entities: CurrentValueSubject<[LoggerMessageEntity], Never>) {
        self.entities = entities
        entities.dropFirst().sink { [weak self] _ in
            self?.showRefreshButtonIfNeeded()
        }.store(in: &cancellables)
        self.refresh()
    }

    func refresh() {
        self.refreshText()
        self.hideRefreshButton()
    }

    private func refreshText() {
        let string = renderer.render(entities.value.reversed())
        self.text.display(string)
    }

    func onLinkTapped(_ url: URL) -> Bool {
        guard url.scheme == "pulse", url.host == "expand", let index = Int(url.lastPathComponent) else {
            return false
        }
        renderer.expanded.insert(index)
        refreshText()
        return true
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
            .previewDisplayName("Network: All")
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
