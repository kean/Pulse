// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(tvOS) || os(watchOS)

final class MainViewModel: ObservableObject {
    let items: [MainViewModelItem]

    let console: ConsoleViewModel

#if !os(watchOS)
    let network: NetworkViewModel
#endif

#if os(iOS)
    let pins: PinsViewModel
    let insights: InsightsViewModel
#endif

    let settings: SettingsViewModel

    let store: LoggerStore

    init(store: LoggerStore, onDismiss: (() -> Void)?) {
        self.store = store

        self.console = ConsoleViewModel(store: store)
        self.console.onDismiss = onDismiss

#if !os(watchOS)
        self.network = NetworkViewModel(store: store)
        self.network.onDismiss = onDismiss
#endif

#if os(iOS)
        self.pins = PinsViewModel(store: store)
        self.pins.onDismiss = onDismiss

        self.insights = InsightsViewModel(store: store)
#endif

        self.settings = SettingsViewModel(store: store)
        self.settings.onDismiss = onDismiss

#if os(iOS)
        self.items = [.console, .network, .pins, !store.isArchive ? .insights : nil, .settings]
            .compactMap { $0 }
#elseif os(tvOS)
        self.items = [.console, .network, .settings]
#else
        self.items = [.console, .network, .pins]
#endif
    }

    func freeMemory() {
        store.viewContext.reset()
    }
}

struct MainViewModelItem: Hashable, Identifiable {
    let title: String
    let imageName: String
    var id: String { title }

#if os(iOS) || os(tvOS)
    static let console = MainViewModelItem(title: "Console", imageName: isPad ? "message" : "message.fill")
    static let network = MainViewModelItem(title: "Network", imageName: {
        if #available(iOS 14.0, *) {
            return "network"
        } else {
            return "icloud.and.arrow.down.fill"
        }
    }())
    static let pins = MainViewModelItem(title: "Pins", imageName: isPad ? "pin" : "pin.fill")
    static let insights = MainViewModelItem(title: "Insights", imageName: isPad ? "chart.pie" : "chart.pie.fill")
    static let settings = MainViewModelItem(title: "Settings", imageName: {
        if #available(iOS 14.0, *) {
            return "gearshape.fill"
        } else {
            return "ellipsis.circle.fill"
        }
    }())
#else
    static let console = MainViewModelItem(title: "Console", imageName: "message")
    static let network = MainViewModelItem(title: "Network", imageName: "icloud.and.arrow.down")
    static let pins = MainViewModelItem(title: "Pins", imageName: "pin")
    static let settings = MainViewModelItem(title: "Settings", imageName: "ellipsis.circle")
#endif
}

extension MainViewModel {
    @ViewBuilder
    func makeView(for item: MainViewModelItem) -> some View {
        switch item {
        case .console:
#if os(watchOS)
            ConsoleView(viewModel: self)
#else
            ConsoleView(viewModel: console)
#endif
#if !os(watchOS)
        case .network:
            NetworkView(viewModel: network)
#if !os(tvOS)
        case .pins:
            PinsView(viewModel: pins)
#endif
#endif
#if os(iOS)
        case .insights:
            InsightsView(viewModel: insights)
#endif
        case .settings:
            SettingsView(viewModel: settings)
        default: fatalError()
        }
    }
}

#if os(iOS) || os(tvOS)
private let isPad = UIDevice.current.userInterfaceIdiom == .pad
#endif

#endif
