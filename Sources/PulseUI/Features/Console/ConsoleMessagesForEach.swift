// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import PulseCore

#if os(watchOS) || os(tvOS)

struct ConsoleMessagesForEach: View {
    let store: LoggerStore
    let messages: [LoggerMessageEntity]

    var body: some View {
        ForEach(messages, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(message: LoggerMessageEntity) -> some View {
        if let request = message.request {
            NetworkRequestRow(store: store, request: request)
        } else {
            NavigationLink(destination: LazyConsoleMessageDetailsView(message: message, store: store)) {
                ConsoleMessagesForEachRow(store: store, message: message)
            }
            .backport.swipeActions(edge: .leading) {
                if #available(tvOS 15.0,  watchOS 8.0, macOS 12.0, *) {
                    PinButton2(viewModel: .init(store: store, message: message))
                        .tint(.blue)
                }
            }
        }
    }
}

private struct NetworkRequestRow: View {
    let store: LoggerStore
    let request: LoggerNetworkRequestEntity

    var body: some View {
        NavigationLink(destination: LazyConsoleNetworkRequestDetailsView(request: request, store: store)) {
            ConsoleNetworkRequestForEachRow(store: store, request: request)
        }
        .backport.swipeActions(edge: .leading) {
            if #available(tvOS 15.0, watchOS 8.0, macOS 12.0, *), let message = request.message {
                PinButton2(viewModel: .init(store: store, message: message))
                    .tint(.blue)
            }
        }
    }
}

struct NetworkMessagesForEach: View {
    let store: LoggerStore
    let entities: [LoggerNetworkRequestEntity]

    var body: some View {
        ForEach(entities, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(request: LoggerNetworkRequestEntity) -> some View {
        NetworkRequestRow(store: store, request: request)
    }
}

/// These exist to make sure views are rendered lazily.
private struct ConsoleNetworkRequestForEachRow: View {
    let store: LoggerStore
    let request: LoggerNetworkRequestEntity

    var body: some View {
        ConsoleNetworkRequestView(viewModel: .init(request: request, store: store))
    }
}

private struct ConsoleMessagesForEachRow: View {
    let store: LoggerStore
    let message: LoggerMessageEntity

    var body: some View {
        ConsoleMessageView(viewModel: .init(message: message, store: store))
    }
}

private struct LazyConsoleMessageDetailsView: View {
    let message: LoggerMessageEntity
    let store: LoggerStore

    var body: some View {
        ConsoleMessageDetailsView(viewModel: .init(store: store, message: message))
    }
}

private struct LazyConsoleNetworkRequestDetailsView: View {
    let request: LoggerNetworkRequestEntity
    let store: LoggerStore

    var body: some View {
        NetworkInspectorView(viewModel: .init(request: request, store: store))
    }
}

#endif
