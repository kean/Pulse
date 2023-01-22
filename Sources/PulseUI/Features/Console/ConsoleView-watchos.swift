// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI
import Pulse

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel

    public init(store: LoggerStore) {
        self.init(viewModel: ConsoleViewModel(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            ConsoleToolbarView(viewModel: viewModel)
            ConsoleListContentView(viewModel: viewModel.list)
        }
        .background(ConsoleRouterView(viewModel: viewModel))
        .navigationTitle("Console")
        .onAppear { viewModel.isViewVisible = true }
        .onDisappear { viewModel.isViewVisible = false }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { viewModel.router.isShowingSettings = true }) {
                    Image(systemName: "gearshape").font(.title3)
                }
            }
        }
    }
}

private struct ConsoleToolbarView: View {
    var consoleViewModel: ConsoleViewModel
    @ObservedObject var viewModel: ConsoleSearchCriteriaViewModel
    @ObservedObject var router: ConsoleRouter

    init(viewModel: ConsoleViewModel) {
        self.consoleViewModel = viewModel
        self.viewModel = viewModel.searchCriteriaViewModel
        self.router = viewModel.router
    }

    var body: some View {
        HStack {
            Button(action: { consoleViewModel.bindingForNetworkMode.wrappedValue.toggle() } ) {
                Image(systemName: "arrow.down.circle")
            }
            .background(consoleViewModel.bindingForNetworkMode.wrappedValue ? Rectangle().foregroundColor(.blue).cornerRadius(8) : nil)

            Button(action: { viewModel.isOnlyErrors.toggle() }) {
                Image(systemName: "exclamationmark.octagon")
            }
            .background(viewModel.isOnlyErrors ? Rectangle().foregroundColor(.red).cornerRadius(8) : nil)

            Button(action: { router.isShowingFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .background(viewModel.isCriteriaDefault ? nil : Rectangle().foregroundColor(.blue).cornerRadius(8))
        }
            .font(.title3)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(store: .mock)
        }
        .navigationTitle("Console")
        .navigationViewStyle(.stack)
    }
}
#endif

#endif
