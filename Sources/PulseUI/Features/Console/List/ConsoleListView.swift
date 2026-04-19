// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
struct ConsoleListView: View {
    var initialSearchText: String?

    @EnvironmentObject var environment: ConsoleEnvironment
    @EnvironmentObject var filters: ConsoleFiltersViewModel

    var body: some View {
        _ConsoleListView(environment: environment, filters: filters, initialSearchText: initialSearchText)
    }
}

@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
private struct _ConsoleListView: View {
    private let environment: ConsoleEnvironment

    @StateObject private var listViewModel: ConsoleListViewModel
    @StateObject private var searchBarViewModel: ConsoleSearchBarViewModel
    @StateObject private var searchViewModel: ConsoleSearchViewModel

    @Environment(\.store) private var store
    @Environment(\.router) private var router

    @State private var editMode: EditMode = .inactive
    @State private var selection = Set<NSManagedObjectID>()
    @State private var shareItems: ShareItems?

    init(environment: ConsoleEnvironment, filters: ConsoleFiltersViewModel, initialSearchText: String? = nil) {
        self.environment = environment

        let listViewModel = ConsoleListViewModel(environment: environment, filters: filters)
        let searchBarViewModel = ConsoleSearchBarViewModel()
        if let initialSearchText {
            searchBarViewModel.text = initialSearchText
        }
        let searchViewModel = ConsoleSearchViewModel(environment: environment, searchBar: searchBarViewModel)
        searchViewModel.isSearching = initialSearchText != nil

        _listViewModel = StateObject(wrappedValue: listViewModel)
        _searchBarViewModel = StateObject(wrappedValue: searchBarViewModel)
        _searchViewModel = StateObject(wrappedValue: searchViewModel)
    }

    var body: some View {
        list
            .environmentObject(listViewModel)
            .environmentObject(searchViewModel)
            .environmentObject(searchBarViewModel)
            .onAppear { listViewModel.isViewVisible = true }
            .onDisappear { listViewModel.isViewVisible = false }
    }

    private var list: some View {
        List(selection: editMode.isEditing ? $selection : nil) {
            ConsoleToolbarView()
                .listRowSeparator(.hidden, edges: .all)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 9, trailing: 16))
            if searchViewModel.isSearching {
                ConsoleSearchListContentView()
            } else {
                ConsoleListContentView()
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(0)
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.defaultMinListRowHeight, 8)
        .environment(\.editMode, $editMode)
        .animation(.default, value: editMode)
        .animation(.default, value: searchViewModel.isSearching)
        .searchable(text: $searchBarViewModel.text, isPresented: $searchViewModel.isSearching)
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .textInputAutocapitalization(.never)
        .onSubmit(of: .search, searchViewModel.onSubmitSearch)
        .disableAutocorrection(true)
        .toolbar { toolbar }
        .onChange(of: editMode) {
            if !$0.isEditing {
                selection.removeAll()
            }
        }
        .sheet(item: $searchViewModel.editingFilterState) { state in
            ConsoleCustomFilterEditSheet(filter: state.filter, fieldGroups: state.filter.availableFieldGroups) {
                searchViewModel.applyEditedFilter($0)
            }
        }
        .sheet(item: $shareItems, content: ShareView.init)
    }

    // MARK: Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            if editMode.isEditing {
                Text(selectionTitle)
                    .font(.headline)
            } else {
                ConsoleNavigationTitleView()
            }
        }
        if editMode.isEditing {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    editMode = .inactive
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Spacer()
            }
            ToolbarItem(placement: .bottomBar) {
                shareMenu
            }
        } else {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { router.isShowingShareStore = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                ConsoleContextMenu(editMode: $editMode)
            }
        }
    }

    // MARK: Selection

    private var selectionTitle: String {
        switch selection.count {
        case 0: return "Select Items"
        case 1: return "1 Selected"
        default: return "\(selection.count) Selected"
        }
    }

    private var shareMenu: some View {
        Menu {
            Button(action: { shareSelectedEntities(as: .pdf) }) {
                Label("PDF", systemImage: "square.and.arrow.up")
            }

            Button(action: { shareSelectedEntities(as: .html) }) {
                Label("HTML", systemImage: "square.and.arrow.up")
            }
            Button(action: { shareSelectedEntities(as: .plainText) }) {
                Label("Text", systemImage: "square.and.arrow.up")
            }
        } label: {
            Label("Share...", systemImage: "square.and.arrow.up")
        }
        .disabled(selection.isEmpty)
    }

    private func shareSelectedEntities(as output: ShareOutput) {
        let entities = selection.compactMap { objectID in
            listViewModel.entities.first(where: { $0.objectID == objectID })
        }
        guard !entities.isEmpty, let store = store as? LoggerStore else { return }
        Task {
            if let items = try? await ShareService.share(entities, store: store, as: output) {
                shareItems = items
            }
        }
    }
}

#endif
