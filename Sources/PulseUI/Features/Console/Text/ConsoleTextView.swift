// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct ConsoleTextView: View {
    @ObservedObject var viewModel: ConsoleTextViewModel

    var body: some View {
        RichTextView(viewModel: viewModel.text)
            .textViewBarItemsHidden(true)
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
    }
}

#if DEBUG
struct ConsoleTextView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleTextView(entities: entities) { _ in
            return // Use default settings
        }
        .frame(width: 600, height: 1000)
    }
}

private let entities = try! LoggerStore.mock.allMessages().filter {
    $0.logLevel != .trace
}

private extension ConsoleTextView {
    init(entities: [NSManagedObject], _ configure: (inout TextRenderer.Options) -> Void) {
        var options = TextRenderer.Options(color: .automatic)
        configure(&options)
        self.init(viewModel: .init(list: .init(store: .mock, source: .store, criteria: .init(store: .mock, index: .init(store: .mock), source: .store)), router: .init()))
    }
}

#endif

#endif
