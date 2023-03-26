// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel
    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        contents
            .navigationTitle("")
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
    }

    @ViewBuilder
    private var contents: some View {
        if #available(macOS 13.0, *) {
            NavigationSplitView(sidebar: {
                ConsoleInspectorsView(viewModel: viewModel)
            }, detail: {
                NavigationStack {
                    detail
                }
            })
        } else {
            NavigationView {
                ConsoleInspectorsView(viewModel: viewModel)
                detail
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if isVertical {
            VSplitView {
                leftPanel
                rightPanel
            }
        } else {
            HSplitView {
                leftPanel
                rightPanel
            }
        }
    }

    @ViewBuilder
    private var leftPanel: some View {
        ConsoleLeftPanelView(viewModel: viewModel, searchBarViewModel: viewModel.searchBarViewModel)
    }

    @ViewBuilder
    private var rightPanel: some View {
        ConsoleRightPanelView(viewModel: viewModel, router: viewModel.router, isVertical: $isVertical)
    }
}

private struct ConsoleLeftPanelView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var searchBarViewModel: ConsoleSearchBarViewModel

    @AppStorage("com-github-kean-pulse-display-mode") private var displayMode: ConsoleDisplayMode = .list

    var body: some View {
        let content = ConsoleContentView(viewModel: viewModel, displayMode: displayMode)
            .frame(minWidth: 200, idealWidth: 400, minHeight: 120, idealHeight: 480)
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Picker("Mode", selection: $displayMode) {
                        Label("List", systemImage: "list.bullet").tag(ConsoleDisplayMode.list)
                        Label("Table", systemImage: "tablecells").tag(ConsoleDisplayMode.table)
                        Label("Text", systemImage: "text.quote").tag(ConsoleDisplayMode.text)
                    }.pickerStyle(.segmented)
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button(action: { viewModel.store.removeAll() }) {
                        Image(systemName: "trash")
                    }
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
                .onSubmit(of: .search, viewModel.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
        } else {
            content
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search, viewModel.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
        }
    }
}

private struct ConsoleRightPanelView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var router: ConsoleRouter
    @Binding var isVertical: Bool

    var body: some View {
        if router.selection != nil {
            ConsoleEntityDetailsView(store: viewModel.store, router: viewModel.router, isVertical: $isVertical)
                .background(Color(UXColor.textBackgroundColor))
                .frame(minWidth: 400, idealWidth: 600, minHeight: 120, idealHeight: 480)
        }
    }
}

private struct ConsoleContentView: View {
    let viewModel: ConsoleViewModel
    let displayMode: ConsoleDisplayMode

    @State private var selectedObjectID: NSManagedObjectID? // Has to use for Table
    @State private var selection: ConsoleSelectedItem?

    @Environment(\.isSearching) private var isSearching

    var body: some View {
        VStack(spacing: 0) {
            ConsoleToolbarView(viewModel: viewModel)
            Divider()
            content
        }
        .onChange(of: selectedObjectID) {
            viewModel.router.selection = $0.map(ConsoleSelectedItem.entity)
        }
        .onChange(of: selection) {
            viewModel.router.selection = $0
        }
        .onChange(of: isSearching) {
            viewModel.isSearching = $0
        }
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            List(selection: $selection) {
                ConsoleSearchView(viewModel: viewModel)
                    .buttonStyle(.plain)
            }.clipped()
        } else {
            switch displayMode {
            case .list:
                List(selection: $selection) {
                    ConsoleListContentView(viewModel: viewModel.listViewModel)
                }.clipped()
            case .table:
                ConsoleTableView(viewModel: viewModel.tableViewModel, selection: $selectedObjectID)
            case .text:
                ConsoleTextView(viewModel: viewModel.textViewModel)
            }
        }
    }
}

struct ConsoleToolbarToggleOnlyErrorsButton: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

    var body: some View {
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .foregroundColor(viewModel.isOnlyErrors ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .help("Toggle Show Only Errors (⇧⌘E)")
    }
}

private enum ConsoleDisplayMode: String {
    case table
    case list
    case text
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
