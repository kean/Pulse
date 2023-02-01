// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(iOS)

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("refactor")
struct ConsoleTextView: View {
    @StateObject private var viewModel = ConsoleTextViewModel()
    @State private var shareItems: ShareItems?
    @State private var isShowingSettings = false
    @ObservedObject private var settings: ConsoleTextViewSettings = .shared

    let entities: CurrentValueSubject<[NSManagedObject], Never>
    let events: PassthroughSubject<ConsoleUpdateEvent, Never>
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
                viewModel.bind(entities: entities, events: events)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let onClose = onClose {
                        Button(action: onClose) {
                            Text("Cancel")
                        }
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
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
            .sheet(item: $shareItems, content: ShareView.init)
            .sheet(isPresented: $isShowingSettings) { settingsView }
    }

    @ViewBuilder
    private var menu: some View {
        Section {
            Button(action: { viewModel.isExpanded.toggle() }) {
                Label(viewModel.isExpanded ? "Collapse Details" : "Expand Details", systemImage: viewModel.isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
            }
        }
        Section {
            Button(action: { isShowingSettings = true }) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        Button(action: viewModel.text.scrollToBottom) {
            Label("Scroll to Bottom", systemImage: "arrow.down")
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
        self.init(entities: .init(entities.reversed()), events: .init(), options: options, onClose: {})
    }
}

#endif

#endif
