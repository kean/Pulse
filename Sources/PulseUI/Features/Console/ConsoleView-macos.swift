// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(macOS)

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel
    @ObservedObject var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    @ObservedObject var searchBarViewModel: ConsoleSearchBarViewModel
    @AppStorage("com-github-kean-pulse-display-mode") private var displayMode: ConsoleDisplayMode = .list
    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false
    @State private var selection: NSManagedObjectID?

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
        self.searchBarViewModel = viewModel.searchBarViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            contents
        }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    toolbarItems
                }
            }
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
            .navigationTitle("Console")
    }

#warning("add search support")
#warning("fix crash when switching modes")
#warning("fix list offset from top")
#warning("fix isViewVisible")
#warning("fix share button when tetx view is shown")
#warning("add toolbar from the bottom")
#warning("hide search result in richtextview")
#warning("implement proper mode switcher")

    @ViewBuilder
    private var toolbarItems: some View {
        Picker("Mode", selection: $displayMode) {
            Label("List", systemImage: "list.bullet").tag(ConsoleDisplayMode.list)
            Label("Table", systemImage: "tablecells").tag(ConsoleDisplayMode.table)
        }.labelStyle(.iconOnly).fixedSize()

        Spacer()

        ConsoleToolbarItems(viewModel: viewModel)

        Spacer()

        Button(action: { isVertical.toggle() }, label: {
            Image(systemName: isVertical ? "square.split.2x1" : "square.split.1x2")
        }).help(isVertical ? "Switch to Horizontal Layout" : "Switch to Vertical Layout")
    }

    @ViewBuilder
    private var contents: some View {
        let split = NotSplitView(
            ConsoleContentView(viewModel: viewModel, searchBarViewModel: viewModel.searchBarViewModel, displayMode: $displayMode, selection: $selection),
            detailsView
                .frame(minWidth: 400, idealWidth: 800, maxWidth: .infinity, minHeight: 120, idealHeight: 480, maxHeight: .infinity, alignment: .center),
            isPanelTwoCollaped: selection == nil,
            isVertical: isVertical
        )

        if #available(macOS 13, *) {
            split
                .environment(\.defaultMinListRowHeight, 8)
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
            split
                .searchable(text: $searchBarViewModel.text)
                .onSubmit(of: .search, viewModel.searchViewModel.onSubmitSearch)
                .disableAutocorrection(true)
        }
    }

    private var detailsView: some View {
        ConsoleEntityDetailsView(viewModel: viewModel.list, selection: $selection)
    }
}

#warning("impleemnt selection in ConsoleSearchView")
private struct ConsoleContentView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var searchBarViewModel: ConsoleSearchBarViewModel
    @Binding var displayMode: ConsoleDisplayMode
    @Binding var selection: NSManagedObjectID?
    @Environment(\.isSearching) private var isSearching

    var body: some View {
        VStack(spacing: 0) {
            content
            Divider()
            HStack {
                ConsoleModePicker(viewModel: viewModel)
                Spacer()
                ConsoleDetailsView(viewModel: viewModel.list)
            }
            .padding(10)
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
                ConsoleTableView(viewModel: viewModel.list, selection: $selection)
            case .list:
                List(selection: $selection) {
                    ConsoleListContentView(viewModel: viewModel.list)
                }
            }
        }
    }
}

private struct ConsoleToolbarItems: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        ConsoleSettingsButton(store: viewModel.store)
        ConsoleToolbarToggleOnlyErrorsButton(viewModel: viewModel.searchCriteriaViewModel)
            .keyboardShortcut("e", modifiers: [.command, .shift])
        FilterPopoverToolbarButton(viewModel: viewModel)
            .keyboardShortcut("f", modifiers: [.command, .option])
    }
}

private struct ConsoleDetailsView: View {
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

private struct ConsoleSettingsButton: View {
    let store: LoggerStore

    @State private var isPresentingSettings = false

    var body: some View {
        Button(action: { isPresentingSettings = true }) {
            Image(systemName: "gearshape")
        }
        .popover(isPresented: $isPresentingSettings, arrowEdge: .bottom) {
            SettingsView(viewModel: .init(store: store))
        }
    }
}

private struct FilterPopoverToolbarButton: View {
    let viewModel: ConsoleViewModel
    @State private var isPresented = false

    var body: some View {
        Button(action: { isPresented.toggle() }, label: {
            Image(systemName: isPresented ? "line.horizontal.3.decrease.circle.fill" : "line.horizontal.3.decrease.circle")
                .foregroundColor(isPresented ? .blue : .secondary)
        })
        .help("Toggle Filters Panel (⌥⌘F)")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            ConsoleSearchCriteriaView(viewModel: viewModel.searchCriteriaViewModel)
                .fixedSize()
        }
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
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleView(store: .mock)
            .previewLayout(.fixed(width: 1000, height: 800))
    }
}
#endif
#endif
