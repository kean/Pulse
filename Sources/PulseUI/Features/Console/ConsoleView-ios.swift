// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS)

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel
    @State private var shareItems: ShareItems?
    @State private var isShowingAsText = false
    @State private var selectedShareOutput: ShareOutput?

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: ConsoleViewModel(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        contentView
            .onAppear(perform: viewModel.onAppear)
            .onDisappear(perform: viewModel.onDisappear)
            .edgesIgnoringSafeArea(.bottom)
            .navigationTitle(viewModel.title)
            .navigationBarItems(
                leading: viewModel.onDismiss.map {
                    Button(action: $0) { Text("Close") }
                },
                trailing: HStack {
                    Menu(content: { shareMenu }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    ConsoleContextMenu(store: viewModel.store, insights: viewModel.insightsViewModel, isShowingAsText: $isShowingAsText)
                }
            )
            .overlay(sharingOverlay) // TODO: use safeAreaInset instead on iOS 15
            .sheet(item: $shareItems, content: ShareView.init)
            .sheet(isPresented: $isShowingAsText) {
                NavigationView {
                    ConsoleTextView(entities: viewModel.entitiesSubject) {
                        isShowingAsText = false
                    }
                }
            }
    }

    @ViewBuilder
    private var shareMenu: some View {
        Button(action: { withAnimation { selectedShareOutput = .plainText } }) {
            Label("Share as Text", systemImage: "square.and.arrow.up")
        }
        Button(action: { withAnimation { selectedShareOutput = .html } }) {
            Label("Share as HTML", systemImage: "square.and.arrow.up")
        }
#if os(iOS)
        Button(action: { withAnimation { selectedShareOutput = .pdf} }) {
            Label("Share as PDF", systemImage: "square.and.arrow.up")
        }
#endif
    }

    @ViewBuilder var sharingOverlay: some View {
        if let output = selectedShareOutput {
            VStack(spacing: 0) {
                Spacer()
                Divider()
                let share = ShareEntitiesView(entities: viewModel.entities, store: viewModel.store, output: output) { item in
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(250)) {
                        shareItems = item
                        withAnimation {
                            selectedShareOutput = nil
                        }
                    }
                }
                if #available(iOS 15, *) {
                    share.background(Material.regular)
                } else {
                    share.background(Color.white)
                }
            }
            .transition(.move(edge: .bottom))
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

private struct ConsoleToolbarView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFilters = false
    @State private var messageCount = 0
    @State private var isSearching = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                let suffix = viewModel.mode == .network ? "Requests" : "Messages"
                SearchBar(
                    title: "\(viewModel.entities.count) \(suffix)",
                    text: $viewModel.filterTerm,
                    isSearching: $isSearching
                )
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
                ConsoleSearchView(viewModel: viewModel.searchViewModel)
                    .inlineNavigationTitle("Filters")
                    .navigationBarItems(trailing: Button("Done") { isShowingFilters = false })
            }
        }
    }

    @ViewBuilder
    private var filters: some View {
        if !viewModel.isNetworkOnly {
            Button(action: viewModel.toggleMode) {
                Image(systemName: viewModel.mode == .network ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }.frame(width: 40, height: 44)
        }
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isOnlyErrors ? .red : .accentColor)
        }.frame(width: 40, height: 44)
        Button(action: { isShowingFilters = true }) {
            Image(systemName: viewModel.searchViewModel.isCriteriaDefault ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
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

extension ConsoleView {
    /// Creates a view pre-configured to display only network requests
    public static func network(store: LoggerStore = .shared) -> ConsoleView {
        ConsoleView(viewModel: .init(store: store, mode: .network))
    }
}
