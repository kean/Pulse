// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(macOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, *)
public struct NetworkView: View {
    @ObservedObject var model: ConsoleViewModel

    @State private var isShowingFilters = false
    @State private var isShowingShareSheet = false
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    public init(store: LoggerStore = .default,
                configuration: ConsoleConfiguration = .default) {
        self.model = ConsoleViewModel(store: store, configuration: configuration, contentType: .network)
    }

    init(model: ConsoleViewModel) {
        self.model = model
    }

    #if os(iOS)
    public var body: some View {
        List {
            quickFiltersView
            ConsoleMessagesForEach(context: model.context, messages: model.messages, searchCriteria: $model.searchCriteria)
        }
        .listStyle(PlainListStyle())
        .navigationBarTitle(Text("Network"))
        .navigationBarItems(leading: model.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } })
    }

    private var quickFiltersView: some View {
        VStack {
            HStack(spacing: 16) {
                SearchBar(title: "Search \(model.messages.count) messages", text: $model.filterTerm)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
    #elseif os(tvOS)
    public var body: some View {
        List {
            ConsoleMessagesForEach(context: model.context, messages: model.messages, searchCriteria: $model.searchCriteria)
        }
    }
    #elseif os(macOS)
    public var body: some View {
        ConsoleMessageListView(model: model)
            .frame(minWidth: 300, idealWidth: 400, maxWidth: 700)
            .toolbar(content: {
                SearchBar(title: "Search", text: $model.filterTerm)
            })
            .background(ShareView(isPresented: $isShowingShareSheet) { model.share(as: .text).items })
    }
    #endif
}

#if DEBUG
@available(iOS 13.0, tvOS 14.0, *)
struct NetworkView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            NetworkView(store: .mock)
            NetworkView(store: .mock)
                .environment(\.colorScheme, .dark)
        }
    }
}
#endif

#endif
