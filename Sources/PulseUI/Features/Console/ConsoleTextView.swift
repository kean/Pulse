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

    let entities: [LoggerMessageEntity]
    var options: ConsoleTextRenderer.Options = .init()

    var body: some View {
        RichTextView(viewModel: viewModel.text)
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.inline)
            .id(ObjectIdentifier(viewModel.text)) // TODO: fix this, should not be required
            .onAppear { viewModel.display(entities, options) }
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
                ConsoleTextView(entities: entitites)
            }
            .previewDisplayName("Default")

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
        self.init(entities: entities, options: options)
    }
}

#endif

#endif
