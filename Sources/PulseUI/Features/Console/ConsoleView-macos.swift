// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
    }

    public var body: some View {
        contents
            .injecting(environment)
            .navigationTitle("")
    }

    @ViewBuilder
    private var contents: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView(sidebar: {
                ConsoleInspectorsView()
            }, detail: {
                NavigationStack {
                    ConsoleMainView(environment: environment)
                }
            })
        } else {
            NavigationView {
                ConsoleInspectorsView()
                ConsoleMainView(environment: environment)
            }
        }
    }
}

/// This view contains the console itself along with the details (no sidebar).
struct ConsoleMainView: View {
    let environment: ConsoleEnvironment
    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false

    var body: some View {
        if isVertical {
            VSplitView {
                contentView
                detailsView.layoutPriority(1)
            }
        } else {
            HSplitView {
                contentView
                detailsView.layoutPriority(1)
            }
        }
    }

    private var contentView: some View {
        ConsoleLeftPanelView(environment: environment, searchBarViewModel: environment.searchBarViewModel)
    }

    private var detailsView: some View {
        ConsoleRightPanelView(isVertical: $isVertical)
    }
}

private struct ConsoleLeftPanelView: View {
    let environment: ConsoleEnvironment
    @ObservedObject var searchBarViewModel: ConsoleSearchBarViewModel

    @AppStorage("com-github-kean-pulse-is-now-enabled") private var isNowEnabled = true

    @State private var isSharingStore = false

    var body: some View {
        let content = ConsoleContentView(environment: environment)
            .frame(minWidth: 200, idealWidth: 400, minHeight: 120, idealHeight: 480)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    toolbarNavigationItems
                }
            }
        if #available(macOS 13, *) {
            content
                .searchable(text: $searchBarViewModel.text, tokens: $searchBarViewModel.tokens, token: {
                    if let image = $0.systemImage {
                        Label($0.title, systemImage: image)
                    } else {
                        Text($0.title)
                    }
                })
                .onSubmit(of: .search, environment.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
        } else {
            content
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search, environment.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
        }
    }

    @ViewBuilder
    private var toolbarNavigationItems: some View {
        if !environment.store.isArchive {
            Toggle(isOn: $isNowEnabled) {
                Image(systemName: "clock")
            }
            Button(action: { isSharingStore = true }) {
                Image(systemName: "square.and.arrow.up")
            }
            .popover(isPresented: $isSharingStore, arrowEdge: .bottom) {
                ShareStoreView(onDismiss: {})
                    .frame(width: 240).fixedSize()
            }
            Button(action: { environment.store.removeAll() }) {
                Image(systemName: "trash")
            }
        }
    }
}

private struct ConsoleRightPanelView: View {
    @Binding var isVertical: Bool

    @EnvironmentObject private var router: ConsoleRouter

    var body: some View {
        if let selection = router.selection {
            ConsoleEntityDetailsRouterView(selection: selection, isVertical: $isVertical)
                .background(Color(UXColor.textBackgroundColor))
                .frame(minWidth: 400, idealWidth: 700, minHeight: 120, idealHeight: 480)
        }
    }
}

private struct ConsoleContentView: View {
    let environment: ConsoleEnvironment

    @State private var selectedObjectID: NSManagedObjectID? // Has to use for Table
    @State private var selection: ConsoleSelectedItem?
    @State private var shareItems: ShareItems?

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        VStack(spacing: 0) {
            if !isSearching {
                ConsoleToolbarView(environment: environment)
                Divider()
            }
            content
        }
        .onChange(of: selectedObjectID) {
            environment.router.selection = $0.map(ConsoleSelectedItem.entity)
        }
        .onChange(of: selection) {
            environment.router.selection = $0
        }
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            List(selection: $selection) {
                ConsoleSearchView(viewModel: environment.searchViewModel)
                    .buttonStyle(.plain)
            }
            .apply(addListContextMenu)
            .onAppear {
                // TODO: search should not depend on list
                environment.listViewModel.isViewVisible = true
                environment.searchViewModel.isViewVisible = true
            }
            .onDisappear {
                environment.listViewModel.isViewVisible = false
                environment.searchViewModel.isViewVisible = false
            }
        } else {
            ScrollViewReader { proxy in
                List(selection: $selection) {
                    ConsoleListContentView(viewModel: environment.listViewModel, proxy: proxy)
                }
                .environment(\.defaultMinListRowHeight, 1)
                .apply(addListContextMenu)
            }
            .onAppear { environment.listViewModel.isViewVisible = true }
            .onDisappear { environment.listViewModel.isViewVisible = false }
        }
    }

    @ViewBuilder
    private func addListContextMenu<T: View>(_ view: T) -> some View {
        if #available(macOS 13, *) {
            view.contextMenu(forSelectionType: ConsoleSelectedItem.self, menu: { _ in }) {
                $0.first.map(makeDetailsView)?.showInWindow()
            }
        } else {
            view
        }
    }

    @ViewBuilder
    private func makeDetailsView(for item: ConsoleSelectedItem) -> some View {
        switch item {
        case .entity(let objectID):
            if let entity = try? environment.store.viewContext.existingObject(with: objectID) {
                ConsoleEntityStandaloneDetailsView(entity: entity)
                    .frame(minWidth: 400, idealWidth: 700, minHeight: 400, idealHeight: 480)
            }
        case .occurrence(let objectID, let occurrence):
            if let entity = try? environment.store.viewContext.existingObject(with: objectID) {
                ConsoleSearchResultView.makeDestination(for: occurrence, entity: entity)
                    .frame(minWidth: 400, idealWidth: 700, minHeight: 400, idealHeight: 480)
            }
        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleView(store: .mock)
            .previewLayout(.fixed(width: 700, height: 400))
    }
}
#endif
#endif
