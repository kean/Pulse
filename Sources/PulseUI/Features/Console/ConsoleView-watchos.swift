// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

#if os(watchOS)

import SwiftUI

struct ConsoleView: View {
    @ObservedObject var viewModel: ConsoleViewModel

    init(viewModel: ConsoleViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List {
            NavigationLink(destination: SettingsView(viewModel: .init(store: viewModel.store))) {
                Label("Settings", systemImage: "gearshape")
            }

            Button(action: { viewModel.isOnlyErrors.toggle() }) {
                Label("Show Errors", systemImage: viewModel.isOnlyErrors ? "exclamationmark.octagon.fill" : "exclamationmark.octagon")
            }
            .listRowBackground(viewModel.isOnlyErrors ? Color.blue.cornerRadius(8) : nil)

            Button(action: { viewModel.isOnlyNetwork.toggle() }) {
                Label("Show Requests", systemImage: "network")
            }
            .listRowBackground(viewModel.isOnlyNetwork ? Color.blue.cornerRadius(8) : nil)

            ConsoleMessagesForEach(messages: viewModel.entities)                
        }
        .navigationTitle("Console")
        .onAppear(perform: viewModel.onAppear)
        .onDisappear(perform: viewModel.onDisappear)
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(viewModel: .init(store: .mock))
        }
    }
}
#endif

#endif
