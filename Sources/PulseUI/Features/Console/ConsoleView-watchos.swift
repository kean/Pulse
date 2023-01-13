// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI
import Pulse

public struct ConsoleView: View {
    @StateObject private var viewModel: ConsoleViewModel

    @State private var isPresentingSettings = false
    @State private var isPresentingFilters = false

    public init(store: LoggerStore) {
        self.init(viewModel: ConsoleViewModel(store: store))
    }

    init(viewModel: ConsoleViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            toolbar
            ConsoleMessagesForEach(messages: viewModel.entities)
        }
        .navigationTitle("Console")
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { isPresentingSettings = true }) {
                    Image(systemName: "gearshape").font(.title3)
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            NavigationView {
                SettingsView(viewModel: .init(store: viewModel.store))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isPresentingSettings = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $isPresentingFilters) {
            NavigationView {
                ConsoleSearchView(viewModel: viewModel.searchViewModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { isPresentingFilters = false }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            Button(action: viewModel.toggleMode) {
                Image(systemName: "arrow.down.circle")
            }
            .background(viewModel.mode == .network ? Rectangle().foregroundColor(.blue).cornerRadius(8) : nil)

            Button(action: { viewModel.isOnlyErrors.toggle() }) {
                Image(systemName: "exclamationmark.octagon")
            }
            .background(viewModel.isOnlyErrors ? Rectangle().foregroundColor(.red).cornerRadius(8) : nil)

            Button(action: { isPresentingFilters = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .background(viewModel.searchViewModel.isCriteriaDefault ? nil : Rectangle().foregroundColor(.blue).cornerRadius(8))
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
