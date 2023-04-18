// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI
import Pulse

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
    }

    public var body: some View {
        List {
            ConsoleToolbarView(environment: environment)
            ConsoleListContentView(viewModel: environment.listViewModel)
        }
        .navigationTitle(environment.title)
        .onAppear { environment.isViewVisible = true }
        .onDisappear { environment.isViewVisible = false }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { environment.router.isShowingSettings = true }) {
                    Image(systemName: "gearshape").font(.title3)
                }
            }
        }
        .injecting(environment)
    }
}

private struct ConsoleToolbarView: View {
    var environment: ConsoleEnvironment
    @ObservedObject private var viewModel: ConsoleSearchCriteriaViewModel
    @Environment(\.router) private var router

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.viewModel = environment.searchCriteriaViewModel
    }

    var body: some View {
        HStack {
            if environment.initialMode == .all {
                Button(action: { environment.bindingForNetworkMode.wrappedValue.toggle() } ) {
                    Image(systemName: "arrow.down.circle")
                }
                .background(environment.bindingForNetworkMode.wrappedValue ? Rectangle().foregroundColor(.blue).cornerRadius(8) : nil)
            }
            Button(action: { viewModel.options.isOnlyErrors.toggle() }) {
                Image(systemName: "exclamationmark.octagon")
            }
            .background(viewModel.options.isOnlyErrors ? Rectangle().foregroundColor(.red).cornerRadius(8) : nil)

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
        .navigationViewStyle(.stack)
    }
}
#endif

#endif
