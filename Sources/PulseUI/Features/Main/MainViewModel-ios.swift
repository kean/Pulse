// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(tvOS)

final class MainViewModel: ObservableObject {
    let items: [MainViewModelItem]

    let consoleViewModel: ConsoleViewModel


    let networkViewModel: NetworkViewModel

#if os(iOS)
    let pinsViewModel: PinsViewModel
    let insightsViewModel: NetworkInsightsViewModel
    let settingsViewModel: SettingsViewModel
#endif

    let store: LoggerStore
    let configuration: ConsoleConfiguration

    init(store: LoggerStore, configuration: ConsoleConfiguration = .default, onDismiss: (() -> Void)?) {
        self.configuration = configuration
        self.store = store

        self.consoleViewModel = ConsoleViewModel(store: store, configuration: configuration)
        self.consoleViewModel.onDismiss = onDismiss

        self.networkViewModel = NetworkViewModel(store: store)
        self.networkViewModel.onDismiss = onDismiss

#if os(iOS)
        self.pinsViewModel = PinsViewModel(store: store)
        self.pinsViewModel.onDismiss = onDismiss

        self.insightsViewModel = NetworkInsightsViewModel(store: store)

        self.settingsViewModel = SettingsViewModel(store: store)
        self.settingsViewModel.onDismiss = onDismiss
#endif

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
            ConsoleView(viewModel: consoleViewModel)
        case .network:
            NetworkView(viewModel: networkViewModel)
#if !os(tvOS)
        case .pins:
            PinsView(viewModel: pinsViewModel)
#endif
#if os(iOS)
        case .insights:
            NetworkInsightsView(viewModel: insightsViewModel)
#endif
#if os(iOS) || os(tvOS)
        case .settings:
#if os(iOS)
            SettingsView(viewModel: settingsViewModel)
#else
            SettingsView(viewModel: consoleViewModel)
#endif
#endif
        default: fatalError()
        }
    }
}

private let isPad = UIDevice.current.userInterfaceIdiom == .pad

#endif
