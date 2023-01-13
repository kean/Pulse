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
 
    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        contents.navigationTitle("Console")
    }

    @ViewBuilder
    private var contents: some View {
        if #available(macOS 13.0, *) {
            ConsoleContainerView(viewModel: viewModel, details: viewModel.details)
        } else {
            LegacyConsoleContainerView(viewModel: viewModel, details: viewModel.details)
        }
    }

    static let contentColumnWidth: CGFloat = 280
}

@available(macOS 13.0, *)
private struct ConsoleContainerView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    let details: ConsoleDetailsRouterViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            sidebar: {
                Siderbar(viewModel: viewModel)
                    .searchable(text: $viewModel.filterTerm)
                    .navigationSplitViewColumnWidth(min: ConsoleView.contentColumnWidth, ideal: 420, max: 640)
            },
            content: {
                ConsoleMessageDetailsRouter(viewModel: details)
                    .navigationSplitViewColumnWidth(ConsoleView.contentColumnWidth)
            },
            detail: {
                EmptyView()
            }
        )
    }
}

private struct LegacyConsoleContainerView: View {
    var viewModel: ConsoleViewModel
    @ObservedObject var details: ConsoleDetailsRouterViewModel

    var body: some View {
        NavigationView {
            Siderbar(viewModel: viewModel)
                .frame(minWidth: 320, idealWidth: 320, maxWidth: 600, minHeight: 120, idealHeight: 480, maxHeight: .infinity)
            ConsoleMessageDetailsRouter(viewModel: details)
                .frame(minWidth: 430, idealWidth: 500, maxWidth: 600, minHeight: 320, idealHeight: 480, maxHeight: .infinity)
            EmptyView()
        }
    }
}

private struct Siderbar: View {
    var viewModel: ConsoleViewModel

    var body: some View {
        ConsoleTableView(viewModel: viewModel.table, onSelected: {
            viewModel.details.select($0)
        })
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                ConsoleToolbarItems(viewModel: viewModel)
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
    }
}

private struct ConsoleToolbarItems: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        ConsoleSettingsButton(store: viewModel.store)
        Spacer()
        ConsoleToolbarModePickerButton(viewModel: viewModel)
            .keyboardShortcut("n", modifiers: [.command, .shift])
        ConsoleToolbarToggleOnlyErrorsButton(isOnlyErrors: $viewModel.isOnlyErrors)
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
                .foregroundColor(isPresented ? .accentColor : .secondary)
        })
        .help("Toggle Filters Panel (⌥⌘F)")
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            ConsoleSearchView(viewModel: viewModel.searchViewModel)
                .fixedSize()
        }
    }
}

private struct ConsoleToolbarModePickerButton: View {
    @ObservedObject var viewModel: ConsoleViewModel

    var body: some View {
        Button(action: viewModel.toggleMode) {
            Image(systemName: viewModel.mode == .network ? "arrow.down.circle.fill" : "arrow.down.circle")
                .foregroundColor(viewModel.mode == .network ? Color.accentColor : Color.secondary)
        }.help("Automatically Scroll to Recent Messages (⇧⌘N)")
    }
}

struct ConsoleToolbarToggleOnlyErrorsButton: View {
    @Binding var isOnlyErrors: Bool

    var body: some View {
        Button(action: { isOnlyErrors.toggle() }) {
            Image(systemName: isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .foregroundColor(isOnlyErrors ? .red : .secondary)
        }.help("Toggle Show Only Errors (⇧⌘E)")
    }
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
