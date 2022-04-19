// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, *)
public struct NetworkView: View {
    @ObservedObject var viewModel: NetworkViewModel

    @State private var isShowingFilters = false
    @State private var isShowingShareSheet = false
    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    public init(store: LoggerStore = .default) {
        self.viewModel = NetworkViewModel(store: store)
    }

    init(viewModel: NetworkViewModel) {
        self.viewModel = viewModel
    }

    #if os(iOS)
    public var body: some View {
        List {
            quickFiltersView
            if !viewModel.entities.isEmpty {
                NetworkMessagesForEach(context: viewModel.context, entities: viewModel.entities)
            }
        }
        .listStyle(PlainListStyle())
        .background(background)
        .navigationBarTitle(Text("Network"))
        .navigationBarItems(leading: viewModel.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } })
    }

    private var quickFiltersView: some View {
        VStack {
            HStack(spacing: 16) {
                SearchBar(title: "Search \(viewModel.entities.count) messages", text: $viewModel.filterTerm)
                Button(action: {
                    isShowingFilters = true
                }) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .foregroundColor(.accentColor)
                }.buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                NetworkFiltersView(viewModel: viewModel.searchCriteria, isPresented: $isShowingFilters)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if viewModel.entities.isEmpty {
            placeholder
        }
    }

    private var placeholder: PlaceholderView {
        let message: String
        if viewModel.searchCriteria.isDefaultSearchCriteria {
            if viewModel.searchCriteria.criteria.dates.isCurrentSessionOnly {
                message = "There are no network requests in the current session."
            } else {
                message = "There are no stored network requests."
            }
        } else {
            message = "There are no network requests for the selected filters."
        }
        return PlaceholderView(imageName: "network", title: "No Requests", subtitle: message)
    }

    #elseif os(tvOS)
    public var body: some View {
        List {
            NetworkMessagesForEach(context: viewModel.context, entities: viewModel.entities)
        }
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
