// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import PulseCore

#if os(watchOS) || os(tvOS) || os(iOS)

struct ConsoleMessagesForEach: View {
    let messages: [LoggerMessageEntity]

    var body: some View {
        ForEach(messages, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(message: LoggerMessageEntity) -> some View {
        if let request = message.request {
            NetworkRequestRow(request: request)
        } else {
            NavigationLink(destination: LazyConsoleeDetailsView(message: message)) {
                ConsoleMessageView(viewModel: .init(message: message))
            }
        }
    }
}

private struct NetworkRequestRow: View {
    let request: LoggerNetworkRequestEntity

    var body: some View {
        NavigationLink(destination: LazyNetworkInspectorView(request: request)) {
            ConsoleNetworkRequestView(viewModel: .init(request: request))
        }
    }
}

// Create the underlying ViewModel lazily.
private struct LazyNetworkInspectorView: View {
    let request: LoggerNetworkRequestEntity

    var body: some View {
        NetworkInspectorView(viewModel: .init(request: request))
    }
}

// Create the underlying ViewModel lazily.
private struct LazyConsoleeDetailsView: View {
    let message: LoggerMessageEntity

    var body: some View {
        ConsoleMessageDetailsView(viewModel: .init(message: message))
    }
}

struct NetworkMessagesForEach: View {
    let entities: [LoggerNetworkRequestEntity]

    var body: some View {
        ForEach(entities, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(request: LoggerNetworkRequestEntity) -> some View {
        NetworkRequestRow(request: request)
    }
}

#endif
