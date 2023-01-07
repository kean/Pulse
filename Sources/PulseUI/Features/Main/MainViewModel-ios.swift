// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(tvOS)

#warning("TODO: simplify this")

final class MainViewModel: ObservableObject {
    let items: [MainViewModelItem]

    let console: ConsoleViewModel
    let network: NetworkViewModel
    let settings: SettingsViewModel

    let store: LoggerStore

    init(store: LoggerStore, onDismiss: (() -> Void)?) {
        self.store = store

        self.console = ConsoleViewModel(store: store, mode: .network)
        self.console.onDismiss = onDismiss

        self.network = NetworkViewModel(store: store)
        self.network.onDismiss = onDismiss

        self.settings = SettingsViewModel(store: store)

        self.items = [.console, .network, .settings]
    }

    func freeMemory() {
        store.viewContext.reset()
    }
}

struct MainViewModelItem: Hashable, Identifiable {
    let title: String
    let imageName: String
    var id: String { title }

    static let console = MainViewModelItem(title: "Console", imageName: "message.fill")
    static let network = MainViewModelItem(title: "Network", imageName: {
        if #available(iOS 14, *) {
            return "network"
        } else {
            return "icloud.and.arrow.down.fill"
        }
    }())
    static let settings = MainViewModelItem(title: "Settings", imageName: {
        if #available(iOS 14, *) {
            return "gearshape.fill"
        } else {
            return "ellipsis.circle.fill"
        }
    }())
}

extension MainViewModel {
    @ViewBuilder
    func makeView(for item: MainViewModelItem) -> some View {
        switch item {
        case .console:
            ConsoleView(viewModel: console)
        case .network:
            NetworkView(viewModel: network)
            SettingsView(viewModel: settings)
        default: fatalError()
        }
    }
}

#endif
