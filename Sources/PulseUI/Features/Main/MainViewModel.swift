// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, *)
final class MainViewModel: ObservableObject {
    let items: [MainViewModelItem]

    let consoleModel: ConsoleViewModel
    let networkModel: NetworkViewModel
    #if !os(tvOS)
    let pinsModel: PinsViewModel
    #endif
    #if os(iOS) || os(tvOS)
    let settingsModel: SettingsViewModel
    #endif

    let configuration: ConsoleConfiguration

    init(store: LoggerStore, configuration: ConsoleConfiguration = .default, onDismiss: (() -> Void)?) {
        self.configuration = configuration

        self.consoleModel = ConsoleViewModel(store: store, configuration: configuration)
        self.consoleModel.onDismiss = onDismiss

        self.networkModel = NetworkViewModel(store: store)
        self.networkModel.onDismiss = onDismiss

        #if os(iOS)
        self.pinsModel = PinsViewModel(store: store)
        self.pinsModel.onDismiss = onDismiss
        #endif

        #if os(iOS) || os(tvOS)
        self.settingsModel = SettingsViewModel(store: store)
        self.settingsModel.onDismiss = onDismiss
        #endif

        #if os(iOS)
        self.items = [.console, .network, .pins, .settings]
        #elseif os(tvOS)
        self.items = [.console, .network, .settings]
        #else
        self.items = [.console, .network, .pins]
        #endif
    }
}

@available(iOS 13.0, tvOS 14.0, *)
struct MainViewModelItem: Hashable, Identifiable {
    let title: String
    let imageName: String
    var id: String { title }

    #if os(iOS) || os(tvOS)
    static let console = MainViewModelItem(title: "Console", imageName: "message.fill")
    static let network = MainViewModelItem(title: "Network", imageName: "network") // "icloud.and.arrow.down.fill")
    static let pins = MainViewModelItem(title: "Pins", imageName: "pin.fill")
    static let settings = MainViewModelItem(title: "Settings", imageName: "gearshape.fill") // "ellipsis.circle.fill")
    #else
    static let console = MainViewModelItem(title: "Console", imageName: "message")
    static let network = MainViewModelItem(title: "Network", imageName: "icloud.and.arrow.down")
    static let pins = MainViewModelItem(title: "Pins", imageName: "pin")
    static let settings = MainViewModelItem(title: "Settings", imageName: "ellipsis.circle")
    #endif
}

@available(iOS 13.0, tvOS 14.0, *)
extension MainViewModel {
    @ViewBuilder
    func makeView(for item: MainViewModelItem) -> some View {
        switch item {
        case .console:
            NavigationView {
                ConsoleView(viewModel: consoleModel)
            }
        case .network:
            NavigationView {
                NetworkView(viewModel: networkModel)
            }
        #if !os(tvOS)
        case .pins:
            NavigationView {
                PinsView(viewModel: pinsModel)
            }
        #endif
        #if os(iOS) || os(tvOS)
        case .settings:
            NavigationView {
                SettingsView(model: settingsModel, console: consoleModel)
            }
        #endif
        default: fatalError()
        }
    }
}

#endif
