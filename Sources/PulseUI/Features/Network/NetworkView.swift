// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(tvOS)

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
        ConsoleTableView(
            header: { NetworkToolbarView(viewModel: viewModel) },
            viewModel: viewModel.table,
            detailsViewModel: viewModel.details
        )
        .overlay(tableOverlay)
        .navigationBarTitle(Text("Network"))
        .navigationBarItems(leading: viewModel.onDismiss.map { Button(action: $0) { Image(systemName: "xmark") } })
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.entities.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }

    #elseif os(tvOS)
    public var body: some View {
        List {
            NetworkMessagesForEach(store: viewModel.store, entities: viewModel.entities)
        }
    }
    #endif
}

#if os(iOS)
private struct NetworkToolbarView: View {
    @ObservedObject var viewModel: NetworkViewModel
    @State private var isShowingFilters = false

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                SearchBar(title: "Search \(viewModel.entities.count) messages", text: $viewModel.filterTerm)
                Spacer().frame(width: 10)
                Button(action: { viewModel.isOnlyErrors.toggle() }) {
                    Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }.frame(width: 40, height: 44)
                Button(action: { isShowingFilters = true }) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }.frame(width: 40, height: 44)
            }.buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                NetworkFiltersView(viewModel: viewModel.searchCriteria, isPresented: $isShowingFilters)
            }
        }
    }
}
#endif

#if DEBUG
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
