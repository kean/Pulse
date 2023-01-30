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
    @AppStorage("com-github-kean-pulse-display-mode") private var displayMode: ConsoleDisplayMode = .list
    @AppStorage("com-github-kean-pulse-is-vertical") private var isVertical = false
    @State private var selection: NSManagedObjectID?

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
    }
#warning("use label for all pickers")

    public var body: some View {
        VStack(spacing: 0) {
            Divider()
            contents
        }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Picker("Mode", selection: $viewModel.mode) {
                        Text("All").tag(ConsoleMode.all)
                        Text("Logs").tag(ConsoleMode.logs)
                        Text("Tasks").tag(ConsoleMode.tasks)
                    }.pickerStyle(.inline)
                }
                ToolbarItemGroup(placement: .automatic) {
                    Picker("Mode", selection: $displayMode) {
                        Label("List", systemImage: "list.bullet").tag(ConsoleDisplayMode.list)
                        Label("Table", systemImage: "tablecells").tag(ConsoleDisplayMode.table)
                        Label("Text", systemImage: "text.quote").tag(ConsoleDisplayMode.text)
                    }.labelStyle(.iconOnly).fixedSize()

                    ConsoleToolbarItems(viewModel: viewModel)

                    Button(action: { isVertical.toggle() }, label: {
                        Image(systemName: isVertical ? "square.split.2x1" : "square.split.1x2")
                    }).help(isVertical ? "Switch to Horizontal Layout" : "Switch to Vertical Layout")
                }
            }
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
            .navigationTitle("Console")
    }

#warning("fix how messages are displaed - are they?")
#warning("add cookies section - do we need summary?")
#warning("disable tabs for empty fields?")
#warning("fix navigation titles")
#warning("should new messages appear at the bottom?")
#warning("fix crash when switching modes")
#warning("one-line message like on both macOS and tvOS?")
#warning("fix list offset from top")
#warning("add search support")
#warning("rework summary")
#warning("fix navigation from metrics view")
#warning("metrics: set max width")
#warning("fix isViewVisible")
#warning("fix reload of the content view")
#warning("add a way to switch between table, list, and text")
#warning("fix share button when tetx view is shown")
#warning("add context menus")
#warning("fix string search options in richtextview")

    private var contents: some View {
        NotSplitView(
            ConsoleContentView(viewModel: viewModel, displayMode: $displayMode, selection: $selection),
            detailsView
                .frame(minWidth: 400, idealWidth: 800, maxWidth: .infinity, minHeight: 120, idealHeight: 480, maxHeight: .infinity, alignment: .center),
            isPanelTwoCollaped: selection == nil,
            isVertical: isVertical
        )
    }

    private var detailsView: some View {
        ConsoleEntityDetailsView(viewModel: viewModel.list, selection: $selection)
    }
}

private struct ConsoleContentView: View {
    let viewModel: ConsoleViewModel
    @Binding var displayMode: ConsoleDisplayMode
    @Binding var selection: NSManagedObjectID?

    var body: some View {
        switch displayMode {
        case .table:
            ConsoleTableView(viewModel: viewModel.list, selection: $selection)
        case .list:
            List(selection: $selection) {
                ConsoleListContentView(viewModel: viewModel.list)
            }
        case .text:
            Text("Not implemented")
        }
    }
}

private struct ConsoleToolbarItems: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        ConsoleSettingsButton(store: viewModel.store)
        ConsoleToolbarModePickerButton(viewModel: viewModel)
            .keyboardShortcut("n", modifiers: [.command, .shift])
        ConsoleToolbarToggleOnlyErrorsButton(viewModel: viewModel.searchCriteriaViewModel)
            .keyboardShortcut("e", modifiers: [.command, .shift])
        FilterPopoverToolbarButton(viewModel: viewModel)
            .keyboardShortcut("f", modifiers: [.command, .option])
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

private struct ConsoleToolbarModePickerButton: View {
    let viewModel: ConsoleViewModel
    @State private var mode: ConsoleMode = .all

    var body: some View {
        Button(action: { mode = (mode == .tasks ? .all : .tasks) }) {
            Image(systemName: mode == .tasks ? "arrow.down.circle.fill" : "arrow.down.circle")
                .foregroundColor(mode == .tasks ? Color.blue : Color.secondary)
        }
        .help("Automatically Scroll to Recent Messages (⇧⌘N)")
        .onChange(of: mode) { viewModel.mode = $0 }
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
            .previewLayout(.fixed(width: 1200, height: 800))
    }
}
#endif
#endif
