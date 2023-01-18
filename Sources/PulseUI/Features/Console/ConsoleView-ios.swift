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

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }


    public var body: some View {
        _ConsoleView(viewModel: viewModel)
    }
}

struct _ConsoleView: View {
    let viewModel: ConsoleViewModel

    @State private var shareItems: ShareItems?
    @State private var isShowingAsText = false
    @State private var selectedShareOutput: ShareOutput?

    var body: some View {
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
                    if let _ = selectedShareOutput {
                        ProgressView()
                            .frame(width: 27, height: 27)
                    } else {
                        Menu(content: { shareMenu }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .disabled(selectedShareOutput != nil)
                    }
                    ConsoleContextMenu(store: viewModel.store, insights: viewModel.insightsViewModel, isShowingAsText: $isShowingAsText)
                }
            )
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
    private var contentView: some View {
        if #available(iOS 15, *) {
            _ConsoleContentView(viewModel: viewModel)
        } else {
            ConsoleListView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var shareMenu: some View {
        Button(action: { share(as: .plainText) }) {
            Label("Share as Text", systemImage: "square.and.arrow.up")
        }
        Button(action: { share(as: .html) }) {
            Label("Share as HTML", systemImage: "square.and.arrow.up")
        }
    }

    private func share(as output: ShareOutput) {
        selectedShareOutput = output
        viewModel.prepareForSharing(as: output) { item in
            selectedShareOutput = nil
            shareItems = item
        }
    }
}

#warning("is setting entities like this OK? should they get updated continuously instead?")

@available(iOS 15.0, *)
private struct _ConsoleContentView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var searchBarViewModel: ConsoleSearchBarViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
        self.searchBarViewModel = viewModel.searchViewModel.searchBar
    }

    var body: some View {
        if #available(iOS 16, tvOS 16, *) {
            ConsoleContentView(viewModel: viewModel)
                .searchable(text: $searchBarViewModel.text, tokens: $searchBarViewModel.tokens, token: {
                    Label($0.title, systemImage: $0.systemImage)
                })
                .onSubmit(of: .search) {
                    viewModel.searchViewModel.onSubmitSearch()
                }
                .disableAutocorrection(true)
        }  else {
            ConsoleContentView(viewModel: viewModel)
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search) {
                    viewModel.searchViewModel.onSubmitSearch()
                }
                .disableAutocorrection(true)
        }
    }
}

@available(iOS 15.0, *)
private struct ConsoleContentView: View {
    let viewModel: ConsoleViewModel
    @Environment(\.isSearching) private var isSearching // important: scope

    @State var isSearchViewVisible = false
    @State var mainSearchViewOpacity = 1.0
    @State var searchViewOpacity = 0.0

    var body: some View {
        if isSearchViewVisible {
            ConsoleSearchView(viewModel: viewModel.searchViewModel)
                .opacity(searchViewOpacity)
                .onAppear {
                    viewModel.searchViewModel.setEntities(viewModel.entities)
                }
                .onChange(of: isSearching) { newValue in
                    isSearchViewVisible = newValue
                    // Workaround for searchable animation issue
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                        withAnimation {
                            searchViewOpacity = 0
                            mainSearchViewOpacity = 1
                        }
                    }
                }
        } else {
            ConsoleListView(viewModel: viewModel)
                .opacity(mainSearchViewOpacity)
                .onChange(of: isSearching) { newValue in
                    isSearchViewVisible = newValue
                    withAnimation {
                        searchViewOpacity = 1
                        mainSearchViewOpacity = 0
                    }
                }
        }
    }
}

private struct ConsoleListView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        List {
            Section(header: ConsoleToolbarView(viewModel: viewModel)) {
                makeForEach(viewModel: viewModel)
            }
        }
        .listStyle(.grouped)
    }
}

private struct ConsoleToolbarView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFilters = false
    @State private var messageCount = 0
    @State private var isSearching = false

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                let suffix = viewModel.mode == .network ? "Requests" : "Messages"
                Text("\(viewModel.entities.count) \(suffix)")
                    .foregroundColor(.secondary)
                Spacer()
                filters
            }
            .buttonStyle(.plain)
            .padding(.bottom, 4)
            .padding(.top, -10)
        }
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
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
            }.frame(width: 40)
        }
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isOnlyErrors ? .red : .accentColor)
        }.frame(width: 40)
        Button(action: { isShowingFilters = true }) {
            Image(systemName: viewModel.searchCriteriaViewModel.isCriteriaDefault ? "line.horizontal.3.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
        }.frame(width: 40)
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
