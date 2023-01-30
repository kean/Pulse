// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

struct ConsoleTextView: View {
    @StateObject private var viewModel = ConsoleTextViewModel()
    @State private var shareItems: ShareItems?
    @State private var isShowingSettings = false
    @ObservedObject private var settings: ConsoleTextViewSettings = .shared

    var entities: CurrentValueSubject<[NSManagedObject], Never>
    var options: TextRenderer.Options?
    var onClose: (() -> Void)?

    var body: some View {
        RichTextView(viewModel: viewModel.text)
            .textViewBarItemsHidden(true)
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let options = options {
                    viewModel.options = options
                }
                viewModel.bind(entities)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let onClose = onClose {
                        Button(action: onClose) {
                            Text("Cancel")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Menu(content: {
                            AttributedStringShareMenu(shareItems: $shareItems) {
                                viewModel.text.textStorage
                            }
                        }, label: {
                            Label("Share...", systemImage: "square.and.arrow.up")
                        })
                        Menu(content: { menu }) {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $shareItems, content: ShareView.init)
            .sheet(isPresented: $isShowingSettings) { settingsView }
    }

    @ViewBuilder
    private var menu: some View {
        Section {
            Button(action: { viewModel.isOrderedAscending.toggle() }) {
                Label("Order by Date", systemImage: viewModel.isOrderedAscending ? "arrow.up" : "arrow.down")
            }
            Button(action: { viewModel.isExpanded.toggle() }) {
                Label(viewModel.isExpanded ? "Collapse Details" : "Expand Details", systemImage: viewModel.isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
            Button(action: viewModel.refresh) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }.disabled(viewModel.isButtonRefreshHidden)
        }
        Section {
            Button(action: { isShowingSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        //            // Unfortunately, this isn't working properly in UITextView (use WebView!)
        //            Button(action: viewModel.text.scrollToBottom) {
        //                Label("Scroll to Bottom", systemImage: "arrow.down")
        //            }
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

private struct ConsoleTextViewSettingsView: View {
    @ObservedObject private var settings: ConsoleTextViewSettings = .shared

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Picker("Color Mode", selection: $settings.colorMode) {
                    Text("Automatic").tag(TextRenderer.ColorMode.automatic)
                    Text("Full").tag(TextRenderer.ColorMode.full)
                    Text("Monochrome").tag(TextRenderer.ColorMode.monochrome)
                }
            }
            Section(header: Text("Request Info")) {
                Toggle("Request Headers", isOn: $settings.showsRequestHeaders)
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

final class ConsoleTextViewModel: ObservableObject {
    var text = RichTextViewModel()
    var options: TextRenderer.Options = .init()

    @Published var isOrderedAscending = false
    @Published var isExpanded = false
    @Published private(set) var isButtonRefreshHidden = true

    private var content: NetworkContent = []
    private var expanded: Set<NSManagedObjectID> = []
    private let settings = ConsoleTextViewSettings.shared
    private var entities: CurrentValueSubject<[NSManagedObject], Never> = .init([])
    private var lastTimeRefreshHidden = Date().addingTimeInterval(-3)
    private var objectIDs: [UUID: NSManagedObjectID] = [:]
    private var cancellables: [AnyCancellable] = []

    init() {
        self.text.onLinkTapped = { [unowned self] in onLinkTapped($0) }
        self.reloadOptions()

        $isOrderedAscending.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refreshText()
        }.store(in: &cancellables)

        $isExpanded.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.expanded.removeAll()
            self?.refreshText()
        }.store(in: &cancellables)
    }

    func bind(_ entities: CurrentValueSubject<[NSManagedObject], Never>) {
        self.entities = entities
        entities.dropFirst().sink { [weak self] _ in
            self?.showRefreshButtonIfNeeded()
        }.store(in: &cancellables)
        self.refresh()
    }

    func reloadOptions() {
        content = makeNetworkContent()
        options.color = settings.colorMode
        text.isLinkDetectionEnabled = false
    }

    func refresh() {
        self.refreshText()
        self.hideRefreshButton()
    }

    private func refreshText() {
        let entities = isOrderedAscending ? entities.value : entities.value.reversed()
        let renderer = TextRenderer(options: options)
        for index in entities.indices {
            let entity = entities[index]
            if let task = entity as? NetworkTaskEntity {
                render(task, at: index, using: renderer)
            } else if let message = entity as? LoggerMessageEntity {
                if let task = message.task {
                    render(task, at: index, using: renderer)
                } else {
                    render(message, at: index, using: renderer)
                }
            } else {
                fatalError("Unsuppported entity: \(entity)")
            }
            if index < entities.endIndex - 1 {
                renderer.addSpacer()
            }
        }
        self.text.display(renderer.make())
    }

    private func render(_ message: LoggerMessageEntity, at index: Int, using renderer: TextRenderer) {
        if let task = message.task {
            render(task, at: index, using: renderer)
        } else {
            renderer.render(message)
        }
    }

    private func render(_ task: NetworkTaskEntity, at index: Int, using renderer: TextRenderer) {
        let isExpanded = isExpanded || expanded.contains(task.objectID)
        guard !isExpanded else {
            return renderer.render(task, content: content) // Render everything
        }

        renderer.render(task, content: [.header])
        renderer.addSpacer()

        let uuid = UUID()
        objectIDs[uuid] = task.objectID
        var attributes = renderer.helper.attributes(role: .body2, weight: .medium)
        attributes[.foregroundColor] = UXColor.systemBlue
        attributes[.link] = URL(string: "pulse://expand/\(uuid.uuidString)")
        attributes[.objectId] = task.objectID
        attributes[.isTechnical] = true
        attributes[.underlineColor] = UXColor.clear
        renderer.append(NSAttributedString(string: "Show Details\n", attributes: attributes))
    }

    private func makeNetworkContent() -> NetworkContent {
        var content = NetworkContent()
        func setEnabled(_ isEnabled: Bool, _ value: NetworkContent) {
            if isEnabled { content.insert(value) } else { content.remove(value) }
        }
        content.insert(.errorDetails)
        setEnabled(settings.showsRequestHeaders, .currentRequestHeaders)
        setEnabled(settings.showsRequestBody, .requestBody)
        setEnabled(settings.showsResponseHeaders, .responseHeaders)
        setEnabled(settings.showsResponseBody, .responseBody)
        return content
    }

    func onLinkTapped(_ url: URL) -> Bool {
        guard url.scheme == "pulse",
              url.host == "expand",
              let uuid = UUID(uuidString: url.lastPathComponent),
              let objectID = objectIDs[uuid] else {
            return false
        }
        expand(objectID)
        return true
    }

    private func expand(_ objectID: NSManagedObjectID) {
        // TODO: both searches are O(N) which isn't great
        guard let task = findTask(withObjectID: objectID) else {
            return
        }
        expanded.insert(objectID)

        var foundRange: NSRange?
        text.textStorage.enumerateAttribute(.objectId, in: NSRange(location: 0, length: text.textStorage.length)) { value, range, stop in
            if value as? NSManagedObjectID == objectID {
                foundRange = range
                stop.pointee = true
            }
        }
        if let range = foundRange {
            let details = TextRenderer(options: options).make { $0.render(task, content: content) }
            text.performUpdates { storage in
                storage.replaceCharacters(in: range, with: details)
            }
        }
    }

    private func findTask(withObjectID objectID: NSManagedObjectID) -> NetworkTaskEntity? {
        if let messages = entities.value as? [LoggerMessageEntity] {
            return messages.first { $0.task?.objectID == objectID }?.task
        } else if let tasks = entities.value as? [NetworkTaskEntity] {
            return tasks.first { $0.objectID == objectID }
        } else {
            fatalError("Unsupported entities: \(entities)")
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
                    $0.color = .full
                }
            }
            .previewDisplayName("Full Color")

            NavigationView {
                ConsoleTextView(entities: entities) {
                    $0.color = .monochrome
                }
            }
            .previewDisplayName("Monochrome")
        }
    }
}

private let entities = try! LoggerStore.mock.allMessages().filter {
    $0.logLevel != .trace
}

private extension ConsoleTextView {
    init(entities: [NSManagedObject], _ configure: (inout TextRenderer.Options) -> Void) {
        var options = TextRenderer.Options(color: .automatic)
        configure(&options)
        self.init(entities: .init(entities.reversed()), options: options, onClose: {})
    }
}

#endif

#endif
