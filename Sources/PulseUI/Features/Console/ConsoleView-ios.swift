// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

public struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isSharing = false
    @State private var isShowingAsText = false

    public init(store: LoggerStore = .shared) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        contentView
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
            .edgesIgnoringSafeArea(.bottom)
            .backport.navigationTitle("Console")
            .navigationBarItems(
                leading: viewModel.onDismiss.map {
                    Button(action: $0) { Image(systemName: "xmark") }
                },
                trailing: HStack {
                    ShareButton { isSharing = true }
                    if #available(iOS 14, *) {
                        ConsoleContextMenu(store: viewModel.store, insights: viewModel.insightsViewModel, isShowingAsText: $isShowingAsText)
                    }
                }
            )
            .sheet(isPresented: $isSharing) {
                if #available(iOS 14, *) {
                    NavigationView {
                        ShareStoreView(store: viewModel.store, isPresented: $isSharing)
                    }.backport.presentationDetents([.medium])
                }
            }
            .backport.fullScreenCover(isPresented: $isShowingAsText) {
                if #available(iOS 14, *) {
                    NavigationView {
                        ConsoleTextView(entities: viewModel.getObservableProperties()) {
                            isShowingAsText = false
                        }
                    }
                }
            }
    }

    @ViewBuilder
    private var contentView: some View {
        ConsoleTableView(
            header: { ConsoleToolbarView(viewModel: viewModel) },
            viewModel: viewModel.table,
            detailsViewModel: viewModel.details
        )
        .overlay(tableOverlay)
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.entities.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }
}

#warning("TODO: display count somewhere else?")
#warning("TODO: duplicate modes and filters in the context menu + search")

private struct ConsoleToolbarView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFilters = false
    @State private var messageCount = 0
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                SearchBar(title: "Search \(viewModel.entities.count) messages", text: $viewModel.filterTerm, isSearching: $isSearching)
                if !isSearching {
                    filters
                } else {
                    Button("Cancel") {
                        isSearching = false
                        viewModel.filterTerm = ""
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 14)
                }
            }.buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                switch viewModel.mode {
                case .all:
                    ConsoleMessageFiltersView(
                        viewModel: viewModel.searchCriteriaViewModel,
                        sharedCriteriaViewModel: viewModel.sharedSearchCriteriaViewModel,
                        isPresented: $isShowingFilters
                    )
                case .network:
                    NetworkFiltersView(
                        viewModel: viewModel.networkSearchCriteriaViewModel,
                        sharedCriteriaViewModel: viewModel.sharedSearchCriteriaViewModel,
                        isPresented: $isShowingFilters
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var filters: some View {
        Button(action: viewModel.toggleMode) {
            Image(systemName: viewModel.mode == .network ? "paperplane.fill" : "paperplane")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }.frame(width: 40, height: 44)
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isOnlyErrors ? .red : .accentColor)
        }.frame(width: 40, height: 44)
        Button(action: { isShowingFilters = true }) {
            Image(systemName: viewModel.isDefaultFilters ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }.frame(width: 40, height: 44)
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(viewModel: .init(store: .mock))
        }
    }
}
#endif

#endif
