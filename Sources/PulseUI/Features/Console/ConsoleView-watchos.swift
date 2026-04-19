// The MIT License (MIT)
//
// Copyright (c) 2020-2026 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI
import Pulse

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment
    @StateObject private var listViewModel: ConsoleListViewModel

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
        let listViewModel = ConsoleListViewModel(environment: environment, filters: environment.filters)
        _listViewModel = StateObject(wrappedValue: listViewModel)
    }

    public var body: some View {
        if #available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *) {
            contents
        } else {
            PlaceholderView(imageName: "xmark.octagon", title: "Unsupported", subtitle: "Pulse requires iOS 18 or later").padding()
        }
    }

    @available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
    private var contents: some View {
        List {
            ConsoleToolbarView(environment: environment)
            ConsoleListContentView()
                .environmentObject(listViewModel)
        }
        .navigationTitle(environment.mode.formattedCount(listViewModel.entities.count))
        .onAppear { listViewModel.isViewVisible = true }
        .onDisappear { listViewModel.isViewVisible = false }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { environment.router.isShowingSessions = true }) {
                    Label("Sessions", systemImage: "list.clipboard")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { environment.router.isShowingSettings = true }) {
                    Image(systemName: "gearshape").font(.title3)
                }
            }
        }
        .injecting(environment)
    }
}

private struct ConsoleToolbarView: View {
    @ObservedObject private var environment: ConsoleEnvironment
    @ObservedObject private var viewModel: ConsoleFiltersViewModel
    @Environment(\.router) private var router

    init(environment: ConsoleEnvironment) {
        self.environment = environment
        self.viewModel = environment.filters
    }

    var body: some View {
        HStack {
            if environment.initialMode == .all {
                Button(action: { environment.bindingForNetworkMode.wrappedValue.toggle() }) {
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
            .background(viewModel.isDefaultFilters(for: environment.mode) ? nil : Rectangle().foregroundColor(.blue).cornerRadius(8))
        }
        .imageScale(.large)
        .font(.footnote)
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
    }
}

#if DEBUG
@available(iOS 18, tvOS 18, macOS 15, watchOS 11, visionOS 1, *)
#Preview {
    NavigationView {
        ConsoleView(store: .mock)
    }
    .navigationViewStyle(.stack)
}
#endif

#endif
