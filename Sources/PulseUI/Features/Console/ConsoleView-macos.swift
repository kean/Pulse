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
    @AppStorage("com-github-kean-pulse-display-mode") private var displayMode: ConsoleDisplayMode = .list

    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        contents.navigationTitle("Console")
    }


    #warning("use label for all pickers")

    @ViewBuilder
    private var contents: some View {
        VStack(spacing: 0) {
            Divider()
            ConsoleContainerView(viewModel: viewModel, displayMode: $displayMode)
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
                }
            }
            .onAppear { viewModel.isViewVisible = true }
            .onDisappear { viewModel.isViewVisible = false }
    }
}

private struct ConsoleContainerView: View {
    let viewModel: ConsoleViewModel
    @ObservedObject var searchCriteriaViewModel: ConsoleSearchCriteriaViewModel
    @State private var selection: NSManagedObjectID?
    @Binding private var displayMode: ConsoleDisplayMode

    init(viewModel: ConsoleViewModel, displayMode: Binding<ConsoleDisplayMode>) {
        self.viewModel = viewModel
        self.searchCriteriaViewModel = viewModel.searchCriteriaViewModel
        self._displayMode = displayMode
    }

#warning("add search support")
#warning("use NotSplitView?")
#warning("metrics: set max width")
#warning("fix isViewVisible")
#warning("fix reload of the content view")
#warning("add a way to switch between table, list, and text")
#warning("fix share button when tetx view is shown")
    var body: some View {
        HSplitView {
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
            ConsoleEntityDetailsView(viewModel: viewModel.list, selection: $selection)
                .id(selection)
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
