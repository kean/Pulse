// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(macOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, *)
final class MainViewModel: ObservableObject {
    let items: [MainViewModelItem]

    let consoleModel: ConsoleViewModel
    let networkModel: ConsoleViewModel
    #if !os(tvOS)
    let pinsModel: PinsViewModel
    #endif
    #if os(iOS) || os(tvOS)
    let settingsModel: SettingsViewModel
    #endif

    init(store: LoggerStore, onDismiss: (() -> Void)?) {
        self.consoleModel = ConsoleViewModel(store: store)
        self.consoleModel.onDismiss = onDismiss

        self.networkModel = ConsoleViewModel(store: store, contentType: .network)
        self.networkModel.onDismiss = onDismiss

        #if os(iOS) || os(macOS)
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
    static let network = MainViewModelItem(title: "Network", imageName: "icloud.fill")
    static let pins = MainViewModelItem(title: "Pins", imageName: "pin.fill")
    static let settings = MainViewModelItem(title: "Settings", imageName: "ellipsis.circle.fill")
    #else
    static let console = MainViewModelItem(title: "Console", imageName: "message")
    static let network = MainViewModelItem(title: "Network", imageName: "icloud")
    static let pins = MainViewModelItem(title: "Pins", imageName: "pin")
    static let settings = MainViewModelItem(title: "Settings", imageName: "ellipsis.circle")
    #endif
}

@available(iOS 13.0, tvOS 14.0, *)
extension MainViewModel {
    @ViewBuilder
    func makeView(for item: MainViewModelItem) -> some View {
        switch item {
        case .console: ConsoleView(model: consoleModel)
        case .network: NetworkView(model: networkModel)
        #if !os(tvOS)
        case .pins: PinsView(model: pinsModel)
        #endif
        #if os(iOS) || os(tvOS)
        case .settings: SettingsView(model: settingsModel, console: consoleModel)
        #endif
        default: fatalError()
        }
    }
}

#endif
