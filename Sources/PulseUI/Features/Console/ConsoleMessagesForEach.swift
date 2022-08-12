// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Pulse

#if os(watchOS) || os(tvOS) || os(iOS)

struct ConsoleMessagesForEach: View {
    let messages: [LoggerMessageEntity]

    var body: some View {
        ForEach(messages, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(message: LoggerMessageEntity) -> some View {
        if let task = message.task {
            NetworkRequestRow(task: task)
        } else {
            NavigationLink(destination: LazyConsoleDetailsView(message: message)) {
                ConsoleMessageView(viewModel: .init(message: message))
            }
        }
    }
}

private struct NetworkRequestRow: View {
    let task: NetworkTaskEntity

    var body: some View {
        NavigationLink(destination: LazyNetworkInspectorView(task: task)) {
            ConsoleNetworkRequestView(viewModel: .init(task: task))
        }
    }
}

// Create the underlying ViewModel lazily.
private struct LazyNetworkInspectorView: View {
    let task: NetworkTaskEntity

    var body: some View {
        NetworkInspectorView(viewModel: .init(task: task))
    }
}

// Create the underlying ViewModel lazily.
private struct LazyConsoleDetailsView: View {
    let message: LoggerMessageEntity

    var body: some View {
        ConsoleMessageDetailsView(viewModel: .init(message: message))
    }
}

struct NetworkMessagesForEach: View {
    let entities: [NetworkTaskEntity]

    var body: some View {
        ForEach(entities, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(task: NetworkTaskEntity) -> some View {
        NetworkRequestRow(task: task)
    }
}

#endif
