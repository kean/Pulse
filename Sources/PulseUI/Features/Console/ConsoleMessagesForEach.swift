// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import PulseCore

#if os(watchOS) || os(tvOS) || os(iOS)

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
            NavigationLink.lazy(destination: {
                ConsoleMessageDetailsView(viewModel: .init(store: store, message: message))
            }, label: {
                ConsoleMessageView(viewModel: .init(message: message, store: store))
            })
        }
    }
}

private struct NetworkRequestRow: View {
    let store: LoggerStore
    let request: LoggerNetworkRequestEntity

    var body: some View {
        NavigationLink.lazy(destination: {
            NetworkInspectorView(viewModel: .init(request: request, store: store))
        }, label: {
            ConsoleNetworkRequestView(viewModel: .init(request: request, store: store))
        })
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

#endif
