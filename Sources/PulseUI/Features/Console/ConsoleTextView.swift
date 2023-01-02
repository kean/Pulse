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
    @State private var isShowingSettings = false
    @ObservedObject private var settings: ConsoleTextViewSettings = .shared

    var entities: CurrentValueSubject<[LoggerMessageEntity], Never>
    var options: ConsoleTextRenderer.Options?
    var onClose: (() -> Void)?

    var body: some View {
        textView
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let options = options {
                    viewModel.options = options
                }
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
            .sheet(isPresented: $isShowingSettings) { settingsView }
    }

    private var textView: some View {
        RichTextView(
            viewModel: viewModel.text,
            isAutomaticLinkDetectionEnabled: settings.isLinkDetectionEnabled,
            isPrincipalSearchBarPlacement: true
        )
    }

    @ViewBuilder
    private var menu: some View {
        Section {
            Button(action: { settings.orderAscending.toggle() }) {
                Label("Order by Date", systemImage: settings.orderAscending ? "arrow.up" : "arrow.down")
            }
            Button(action: { settings.isCollapsingResponses.toggle() }) {
                Label(settings.isCollapsingResponses ? "Expand Responses" : "Collapse Responses", systemImage: settings.isCollapsingResponses ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
            }
            Button(action: { isShowingSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
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

    private var settingsView: some View {
        NavigationView {
            ConsoleTextViewSettingsView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    isShowingSettings = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                        viewModel.reloadOptions()
                        viewModel.refresh()
                    }
                })
        }
    }
}

@available(iOS 14.0, *)
private struct ConsoleTextViewSettingsView: View {
    @ObservedObject private var settings: ConsoleTextViewSettings = .shared

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Toggle("Monochrome", isOn: $settings.isMonochrome)
                Toggle("Syntax Highlighting", isOn: $settings.isSyntaxHighlightingEnabled)
                Toggle("Link Detection", isOn: $settings.isLinkDetectionEnabled)
                Stepper("Font Size: \(settings.fontSize)", value: $settings.fontSize)
            }
            Section(header: Text("Request Info")) {
                Toggle("Request Headers", isOn: $settings.showsTaskRequestHeader)
                Toggle("Response Headers", isOn: $settings.showsResponseHeaders)
                Toggle("Request Body", isOn: $settings.showsRequestBody)
                Toggle("Response Body", isOn: $settings.showsResponseBody)
            }
            Section {
                Button("Reset Settings") {
                    settings.reset()
                }
                .foregroundColor(.red)
            }
        }
    }
}

@available(iOS 14.0, *)
final class ConsoleTextViewModel: ObservableObject {
    private var entities: CurrentValueSubject<[LoggerMessageEntity], Never> = .init([])
    private let renderer = ConsoleTextRenderer()

    private var cancellables: [AnyCancellable] = []

    var options: ConsoleTextRenderer.Options = .init()

    private let settings = ConsoleTextViewSettings.shared

    let text: RichTextViewModel
    @Published private(set) var isButtonRefreshHidden = true
    private var lastTimeRefreshHidden = Date().addingTimeInterval(-3)

    init() {
        self.text = RichTextViewModel(string: "")
        self.text.onLinkTapped = { [unowned self] in onLinkTapped($0) }
        self.reloadOptions()

        ConsoleTextViewSettings.shared.$orderAscending.dropFirst().sink { [weak self] _ in
            self?.refreshText()
        }.store(in: &cancellables)

        ConsoleTextViewSettings.shared.$isCollapsingResponses.dropFirst().sink { [weak self] isCollasped in
            self?.options.isBodyExpanded = !isCollasped
            self?.renderer.expanded.removeAll()
            self?.refreshText()
        }.store(in: &cancellables)
    }

    func bind(_ entities: CurrentValueSubject<[LoggerMessageEntity], Never>) {
        self.entities = entities
        entities.dropFirst().sink { [weak self] _ in
            self?.showRefreshButtonIfNeeded()
        }.store(in: &cancellables)
        self.refresh()
    }

    func reloadOptions() {
        options.isBodyExpanded = !settings.isCollapsingResponses
        options.isMonocrhome = settings.isMonochrome
        options.isBodySyntaxHighlightingEnabled = settings.isSyntaxHighlightingEnabled
        options.fontSize = CGFloat(settings.fontSize)
        if settings.showsTaskRequestHeader {
            options.networkContent.insert(.currentRequestHeaders)
            options.networkContent.insert(.originalRequestHeaders)
        } else {
            options.networkContent.remove(.currentRequestHeaders)
            options.networkContent.remove(.originalRequestHeaders)
        }
        if settings.showsRequestBody {
            options.networkContent.insert(.requestBody)
        } else {
            options.networkContent.remove(.requestBody)
        }
        if settings.showsResponseHeaders {
            options.networkContent.insert(.responseHeaders)
        } else {
            options.networkContent.remove(.responseHeaders)
        }
        if settings.showsResponseBody {
            options.networkContent.insert(.responseBody)
        } else {
            options.networkContent.remove(.responseBody)
        }

        text.textView?.isAutomaticLinkDetectionEnabled = settings.isLinkDetectionEnabled
    }

    func refresh() {
        self.refreshText()
        self.hideRefreshButton()
    }

    private func refreshText() {
        let entities = settings.orderAscending ? entities.value : entities.value.reversed()
        let string = renderer.render(entities, options: options)
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
