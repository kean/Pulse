// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

#warning("TODO: simplify toolbar (move everyghig to more)")

import SwiftUI

struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    @State private var isSettingsPresented = false

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            let stack = HStack {
                Button(action: viewModel.toggleMode) {
                    Image(systemName: "paperplane").font(.title3)
                }
                .background(viewModel.mode == .network ? Rectangle().foregroundColor(.blue).cornerRadius(8) : nil)
                Button(action: { viewModel.isOnlyErrors.toggle() }) {
                    Image(systemName: "exclamationmark.octagon").font(.title3)
                }
                .background(viewModel.isOnlyErrors ? Rectangle().foregroundColor(.red).cornerRadius(8) : nil)
                Button(action: { isSettingsPresented = true }) {
                    Image(systemName: "gearshape").font(.title3)
                }
            }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
            if #available(watchOS 8.0, *) {
                stack
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
            } else {
                stack
            }
            ConsoleMessagesForEach(messages: viewModel.entities)
        }
        .navigationTitle("Console")
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView(viewModel: .init(store: viewModel.store))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isSettingsPresented = false
                        }
                    }
                }
        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(viewModel: .init(store: .mock))
        }
        .navigationTitle("Console")
        .navigationViewStyle(.stack)
    }
}
#endif

#endif
