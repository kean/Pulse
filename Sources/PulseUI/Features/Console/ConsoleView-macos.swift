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
    @ObservedObject var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    @ObservedObject var searchBarViewModel: ConsoleSearchBarViewModel
    @ObservedObject private var router: ConsoleRouter
    @AppStorage("com-github-kean-pulse-display-mode") private var displayMode: ConsoleDisplayMode = .list
    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
        self.searchBarViewModel = viewModel.searchBarViewModel
        self.router = viewModel.router
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
                detail
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
        let content = ConsoleContentView(viewModel: viewModel, displayMode: $displayMode)
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
                    ConsoleToolbarToggleOnlyErrorsButton(viewModel: viewModel.searchCriteriaViewModel)
                        .keyboardShortcut("e", modifiers: [.command, .shift])
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

    @ViewBuilder
    private var rightPanel: some View {
        if router.selection != nil {
            if #available(macOS 13.0, *) {
                NavigationStack {
                    rightPanelContents
                }
            } else {
                rightPanelContents
            }
        }
    }

    private var rightPanelContents: some View {
        ConsoleEntityDetailsView(viewModel: viewModel.list, router: viewModel.router, isVertical: $isVertical)
            .background(Color(UXColor.textBackgroundColor))
            .frame(minWidth: 400, idealWidth: 600, minHeight: 120, idealHeight: 480)
    }
}

private struct ConsoleContentView: View {
    var viewModel: ConsoleViewModel
    @Binding var displayMode: ConsoleDisplayMode
    @State private var selectedObjectID: NSManagedObjectID? // Has to use for Table
    @State private var selection: ConsoleSelectedItem?
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            HStack {
                ConsoleModePicker(viewModel: viewModel)
                Spacer()
                ConsoleLogsDetailsView(viewModel: viewModel.list)
            }
            .padding(EdgeInsets(top: 7, leading: 10, bottom: 9, trailing: 10))
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
            }
        } else {
            switch displayMode {
            case .table:
                ConsoleTableView(viewModel: viewModel.list, selection: $selectedObjectID)
            case .list:
                List(selection: $selection) {
                    ConsoleListContentView(viewModel: viewModel.list)
                }
            case .text:
                ConsoleTextView(viewModel: viewModel.textViewModel)
            }
        }
    }
}

private struct ConsoleLogsDetailsView: View {
    @ObservedObject var viewModel: ConsoleListViewModel

    var body: some View {
        detailsText
            .lineLimit(1)
            .font(ConsoleConstants.fontTitle)
            .foregroundColor(.secondary)
    }

    private var detailsText: Text {
        let details = viewModel.taskDetails
        return Text(Image(systemName: "arrow.up")).fontWeight(.light) +
        Text(" " + byteCount(for: details.totalRequestBodySize)) +
        Text("   ") +
        Text(Image(systemName: "arrow.down")).fontWeight(.light) +
        Text(" " + byteCount(for: details.totalResponseSize))
    }

    private func byteCount(for size: Int64) -> String {
        guard size > 0 else { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: size)
    }
}

struct ConsoleToolbarToggleOnlyErrorsButton: View {
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel

    var body: some View {
        Button(action: { viewModel.isOnlyErrors.toggle() }) {
            Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .foregroundColor(viewModel.isOnlyErrors ? .red : .secondary)
        }.help("Toggle Show Only Errors (⇧⌘E)")
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
