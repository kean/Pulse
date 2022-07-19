// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(macOS)

public struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State var isFiltersPaneHidden = true
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var shared: ShareItems?

    public init(store: LoggerStore = .default, configuration: ConsoleConfiguration = .default) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    #warning("TODO: add more toolbar items")
    public var body: some View {
//        VStack(spacing: 0) {
//            Divider()
            HStack(spacing: 0) {
                NavigationView {
                    contentView
                }
                filterPanel
            }
//        }
    }

    private var contentView: some View {
        List {
//            ConsoleToolbarView(viewModel: viewModel)
            ConsoleMessagesForEach(store: viewModel.store, messages: viewModel.messages)
        }
        .toolbar {
//                ToolbarItemGroup(placement: .navigation) {
//                    ConsoleToolbarModePickerView(model: viewModel.mode)
//                }
//                ToolbarItemGroup(placement: .principal) {
//                    if let client = viewModel.remote.client {
//                        RemoteLoggerClientStatusView(client: client)
//                        RemoteLoggerTooglePlayButton(client: client)
//                        ConsoleNowView(model: viewModel.toolbar)
//                        Button(action: client.clear, label: {
//                            Label("Clear", systemImage: "trash")
//                        }).help("Remove All Messages (⌘K)")
//                    }
//                }
//                ToolbarItem {
//                    Spacer()
//                }
            ToolbarItemGroup(placement: .automatic) {
//                    ConsoleToolbarSearchBar(model: viewModel)
                ConsoleToolbarToggleOnlyErrorsButton(isOnlyErrors: $viewModel.isOnlyErrors)
                ConsoleToolbarToggleFiltersButton(isFiltersPaneHidden: $isFiltersPaneHidden)
//                    ConsoleToolbarToggleVerticalView(model: viewModel.toolbar)
            }
        }
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.messages.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var filterPanel: some View {
        if !isFiltersPaneHidden {
            HStack(spacing: 0) {
                ExDivider()
                ConsoleContainerFiltersPanel(viewModel: viewModel)
            }
        }
    }
}

private struct ConsoleToolbarToggleFiltersButton: View {
    @Binding var isFiltersPaneHidden: Bool

    var body: some View {
        Button(action: { isFiltersPaneHidden.toggle() }, label: {
            Image(systemName: isFiltersPaneHidden ? "line.horizontal.3.decrease.circle" : "line.horizontal.3.decrease.circle.fill")
        }).foregroundColor(isFiltersPaneHidden ? .secondary : .accentColor)
            .help("Toggle Filters Panel (⌥⌘F)")
    }
}

private struct ConsoleToolbarToggleOnlyErrorsButton: View {
    @Binding var isOnlyErrors: Bool

    var body: some View {
        Button(action: { isOnlyErrors.toggle() }) {
            Image(systemName: isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
        }.foregroundColor(isOnlyErrors ? .accentColor : .secondary)
            .help("Toggle Show Only Errors (⇧⌘E)")
    }
}

#warning("TODO: implement this")
//private struct ConsoleToolbarView: View {
//    @ObservedObject var viewModel: ConsoleViewModel
//    @State private var isShowingFilters = false
//
//    var body: some View {
//        VStack(spacing: 8) {
//            HStack(spacing: 0) {
//                SearchBar(title: "Search \(viewModel.messages.count) messages", text: $viewModel.filterTerm)
//                Spacer().frame(width: 10)
//                Button(action: { viewModel.isOnlyErrors.toggle() }) {
//                    Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
//                        .font(.system(size: 20))
//                        .foregroundColor(.accentColor)
//                }.frame(width: 40, height: 44)
//                Button(action: { isShowingFilters = true }) {
//                    Image(systemName: "line.horizontal.3.decrease.circle")
//                        .font(.system(size: 20))
//                        .foregroundColor(.accentColor)
//                }.frame(width: 40, height: 44)
//            }.buttonStyle(.plain)
//        }
//        .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
//        .sheet(isPresented: $isShowingFilters) {
//            NavigationView {
//                ConsoleFiltersView(viewModel: viewModel.searchCriteria)
//            }
//        }
//    }
//}

private struct ConsoleContainerFiltersPanel: View {
    let viewModel: ConsoleViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    #warning("TODO: enable filtesr")
    var body: some View {
//        switch mode.mode {
//        case .list, .text:
        ConsoleFiltersView(viewModel: viewModel.searchCriteria)
                .frame(width: 200)
//        case .network:
//            NetworkFiltersView(viewModel: viewModel.network.filters)
//                .frame(width: 200)
//        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            NavigationView {
                ConsoleView(viewModel: .init(store: .mock))
            }
            NavigationView {
                ConsoleView(viewModel: .init(store: .mock))
            }.environment(\.colorScheme, .dark)
        }
    }
}
#endif
#endif
