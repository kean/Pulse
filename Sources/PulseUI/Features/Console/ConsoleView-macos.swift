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
    @ObservedObject private var router: ConsoleRouter
    @AppStorage("com-github-kean-pulse-display-mode") private var displayMode: ConsoleDisplayMode = .list
    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false
    @AppStorage("com-github-kean-pulse-is-inspector-hidden") private var isInspectorHidden = true

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
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
                contents
                if !isInspectorHidden {
                    Divider()
                        .background(Color.black)
                    ConsoleInspectorsView(viewModel: viewModel)
                        .frame(width: 275)
                }
            }
        }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Picker("Mode", selection: $displayMode) {
                        Label("List", systemImage: "list.bullet").tag(ConsoleDisplayMode.list)
                        Label("Table", systemImage: "tablecells").tag(ConsoleDisplayMode.table)
                        Label("Text", systemImage: "text.quote").tag(ConsoleDisplayMode.text)
                    }.pickerStyle(.segmented)
                }
                ToolbarItemGroup(placement: .automatic) {
                    Spacer()
                    toolbarItems
                }
            }
            .navigationTitle("")
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
    }

    @ViewBuilder
    private var toolbarItems: some View {
        ConsoleToolbarItems(viewModel: viewModel)
        Button(action: { isVertical.toggle() }, label: {
            Image(systemName: isVertical ? "square.split.2x1" : "square.split.1x2")
        }).help(isVertical ? "Switch to Horizontal Layout" : "Switch to Vertical Layout")
        Button(action: { withAnimation { isInspectorHidden.toggle() } }, label: {
            Image(systemName: "sidebar.right")
        })
    }

    @ViewBuilder
    private var contents: some View {
        let split = NotSplitView(
            ConsoleContentView(viewModel: viewModel, displayMode: $displayMode),
            detailsView
                .frame(minWidth: 400, idealWidth: 800, maxWidth: .infinity, minHeight: 120, idealHeight: 480, maxHeight: .infinity, alignment: .center),
            isPanelTwoCollaped: router.selection == nil,
            isVertical: isVertical
        )

        if #available(macOS 13, *) {
            split
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
        ConsoleEntityDetailsView(viewModel: viewModel.list, router: viewModel.router)
    }
}

private struct ConsoleContentView: View {
    var viewModel: ConsoleViewModel
    @Binding var displayMode: ConsoleDisplayMode
    @State var selection: NSManagedObjectID?
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
            .padding(.top, 7)
            .padding(.bottom, 9)
            .padding(.horizontal, 10)
        }
        .onChange(of: selection) {
            viewModel.router.selection = $0.map(ConsoleSelectedItem.entity)
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
            case .text:
                ConsoleTextView(viewModel: viewModel.textViewModel)
            }
        }
    }
}

private struct ConsoleToolbarItems: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        ConsoleToolbarToggleOnlyErrorsButton(viewModel: viewModel.searchCriteriaViewModel)
            .keyboardShortcut("e", modifiers: [.command, .shift])
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
