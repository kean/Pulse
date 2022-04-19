// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import PulseCore

#if os(watchOS) || os(tvOS) || os(iOS)

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct ConsoleMessagesForEach: View {
    let context: AppContext
    let messages: [LoggerMessageEntity]
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    var body: some View {
        ForEach(messages, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(message: LoggerMessageEntity) -> some View {
        if let request = message.request {
            NavigationLink(destination: LazyConsoleNetworkRequestDetailsView(request: request, context: context)) {
                ConsoleNetworkRequestForEachRow(context: context, request: request)
            }
            .backport.swipeActions(edge: .leading) {
                if #available(iOS 15.0, watchOS 8.0, *) {
                    PinButton2(viewModel: .init(store: context.store, message: message))
                        .tint(.blue)
                }
            }
        } else {
            NavigationLink(destination: LazyConsoleMessageDetailsView(message: message, context: context)) {
                ConsoleMessagesForEachRow(context: context, message: message, searchCriteriaViewModel: searchCriteriaViewModel)
            }
            .backport.swipeActions(edge: .leading) {
                if #available(iOS 15.0, watchOS 8.0, *) {
                    PinButton2(viewModel: .init(store: context.store, message: message))
                        .tint(.blue)
                }
            }
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
struct NetworkMessagesForEach: View {
    let context: AppContext
    let entities: [LoggerNetworkRequestEntity]

    var body: some View {
        ForEach(entities, id: \.objectID, content: makeListItem)
    }

    @ViewBuilder
    private func makeListItem(request: LoggerNetworkRequestEntity) -> some View {
        NavigationLink(destination: LazyConsoleNetworkRequestDetailsView(request: request, context: context)) {
            ConsoleNetworkRequestForEachRow(context: context, request: request)
        }
        .backport.swipeActions(edge: .leading) {
            if #available(iOS 15.0, watchOS 8.0, *), let message = request.message {
                PinButton2(viewModel: .init(store: context.store, message: message))
                    .tint(.blue)
            }
        }
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
private struct ConsoleNetworkRequestForEachRow: View {
    let context: AppContext
    let request: LoggerNetworkRequestEntity

    @State private var sharedItems: ShareItems?

    var body: some View {
        #if os(iOS)
        contents
            .contextMenu {
                NetworkMessageContextMenu(request: request, context: context, sharedItems: $sharedItems)
            }
            .sheet(item: $sharedItems) { ShareView($0).id($0.id) }
        #else
        contents
        #endif
    }

    var contents: some View {
        ConsoleNetworkRequestView(viewModel: .init(request: request, context: context))
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
private struct ConsoleMessagesForEachRow: View {
    let context: AppContext
    let message: LoggerMessageEntity
    let searchCriteriaViewModel: ConsoleSearchCriteriaViewModel

    @State private var isShowingShareSheet = false

    var body: some View {
        #if os(iOS)
        contents
            .contextMenu {
                ConsoleMessageContextMenu(message: message, context: context, isShowingShareSheet: $isShowingShareSheet, searchCriteriaViewModel: searchCriteriaViewModel)
            }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareView(activityItems: [context.share.share(message)])
            }
        #else
        contents
        #endif
    }

    var contents: some View {
        ConsoleMessageView(viewModel: .init(message: message, context: context))
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
private struct LazyConsoleMessageDetailsView: View {
    let message: LoggerMessageEntity
    let context: AppContext

    var body: some View {
        ConsoleMessageDetailsView(viewModel: .init(context: context, message: message))
    }
}

@available(iOS 13.0, tvOS 14.0, watchOS 7.0, *)
private struct LazyConsoleNetworkRequestDetailsView: View {
    let request: LoggerNetworkRequestEntity
    let context: AppContext

    var body: some View {
        NetworkInspectorView(viewModel: .init(request: request, context: context))
    }
}

#endif
