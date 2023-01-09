// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: remoev ConsoleViewModel and ConsoleContainerView")
#warning("TODO: experiemnt with different navigation styles on macos")
#warning("TODO: show message details in the details and metadata in main panel")
#warning("TDO: move search button somewhere else")
#warning("TODO: fill-out filter button when custom selected")

#warning("TODO: can we reuse more with iOS?")

#if os(macOS)

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel
    @State private var isShowingSettings = false
    @State private var isShowingShareSheet = false
    @State private var shareItems: ShareItems?
 
    public init(store: LoggerStore = .shared) {
        self.init(viewModel: .init(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        contents
            .navigationTitle("Console")
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button(action: { isShowingSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    Button(action: { isShowingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .popover(isPresented: $isShowingShareSheet, arrowEdge: .top) {
                        ShareStoreView(store: viewModel.store, isPresented: $isShowingShareSheet) { item in
                            isShowingShareSheet = false
                            DispatchQueue.main.async {
                                shareItems = item
                            }
                        }
                    }
                    .popover(item: $shareItems) { item in
                        ShareView(item)
                            .fixedSize()
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(viewModel: .init(store: viewModel.store))
            }
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

#warning("TODO: this is incomplete")

@available(macOS 13.0, *)
private struct ConsoleContainerView: View {
    var viewModel: ConsoleViewModel
    @ObservedObject var details: ConsoleDetailsRouterViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            sidebar: {
                Siderbar(viewModel: viewModel)
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
    let viewModel: ConsoleViewModel

    @State private var isSearchBarActive = false

    var body: some View {
        VStack(spacing: 0) {
            ConsoleTableView(viewModel: viewModel.table, onSelected: {
                viewModel.details.select($0)
            })
            ConsoleToolbarSearchBar(viewModel: viewModel, isSearchBarActive: $isSearchBarActive)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                ConsoleToolbarItems(viewModel: viewModel, isSearchBarActive: $isSearchBarActive)
            }
        }
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .background(NavigationTitleUpdater(title: viewModel.title, viewModel: viewModel.table))
    }
}

private struct ConsoleToolbarItems: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @Binding var isSearchBarActive: Bool

    var body: some View {
        Button(action: {
            // TODO: Refactor
            isSearchBarActive = true
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
                viewModel.onFind.send()
            }
        }) {
            Image(systemName: "magnifyingglass")
        }.keyboardShortcut("f")
        ConsoleToolbarToggleOnlyErrorsButton(isOnlyErrors: $viewModel.isOnlyErrors)
            .keyboardShortcut("e", modifiers: [.command, .shift])
        ConsoleToolbarModePickerButton(viewModel: viewModel)
            .keyboardShortcut("n", modifiers: [.command, .shift])
        FilterPopoverToolbarButton(viewModel: viewModel)
            .keyboardShortcut("f", modifiers: [.command, .option])
    }
}

#warning("TODO: remove search button & always dispaly filter at the top or bottom")
private struct ConsoleToolbarSearchBar: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @Binding var isSearchBarActive: Bool

    var body: some View {
        if isSearchBarActive {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    SearchBar(title: "Filter", text: $viewModel.filterTerm, onFind: viewModel.onFind, onEditingChanged: { isEditing in
                        isSearchBarActive = isEditing
                    }, onReturn: { })
                    .frame(maxWidth: isSearchBarActive ? 320 : 200)
                    Spacer()
                }.padding(6)
            }
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
            ConsoleFiltersView(viewModel: viewModel)
                .frame(width: ConsoleFilters.preferredWidth)
                .padding(.bottom, 16)
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

private struct NavigationTitleUpdater: View {
    let title: String
    @ObservedObject var viewModel: ConsoleTableViewModel

    var body: some View {
        EmptyView().navigationSubtitle(message)
    }

    private var message: String {
        let count = viewModel.entities.count
        let title = count % 10 == 1 ? String(title.dropLast()) : title
        return "\(count) \(title)"
    }
}

struct ConsoleToolbarToggleOnlyErrorsButton: View {
    @Binding var isOnlyErrors: Bool

    var body: some View {
        Button(action: { isOnlyErrors.toggle() }) {
            Image(systemName: isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                .foregroundColor(isOnlyErrors ? .accentColor : .secondary)
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
