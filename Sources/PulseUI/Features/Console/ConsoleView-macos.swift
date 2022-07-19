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
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var shared: ShareItems?

    public init(store: LoggerStore = .default, configuration: ConsoleConfiguration = .default) {
        self.viewModel = ConsoleViewModel(store: store)
    }

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        contentView
    }

    private var contentView: some View {
        List {
            ConsoleToolbarView(viewModel: viewModel)
            ConsoleMessagesForEach(store: viewModel.store, messages: viewModel.messages)
        }
    }

    @ViewBuilder
    private var tableOverlay: some View {
        if viewModel.messages.isEmpty {
            PlaceholderView.make(viewModel: viewModel)
        }
    }
}

private struct ConsoleToolbarView: View {
    @ObservedObject var viewModel: ConsoleViewModel
    @State private var isShowingFilters = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                SearchBar(title: "Search \(viewModel.messages.count) messages", text: $viewModel.filterTerm)
                Spacer().frame(width: 10)
                Button(action: { viewModel.isOnlyErrors.toggle() }) {
                    Image(systemName: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }.frame(width: 40, height: 44)
                Button(action: { isShowingFilters = true }) {
                    Image(systemName: "line.horizontal.3.decrease.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }.frame(width: 40, height: 44)
            }.buttonStyle(.plain)
        }
        .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
        .sheet(isPresented: $isShowingFilters) {
            NavigationView {
                ConsoleFiltersView(viewModel: viewModel.searchCriteria)
            }
        }
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
