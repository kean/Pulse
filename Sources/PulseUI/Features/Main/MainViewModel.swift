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
    let pinsModel: ConsoleViewModel
    #endif
    #if os(iOS) || os(tvOS)
    let settingsModel: SettingsViewModel
    #endif
    
    let configuration: ConsoleConfiguration

    init(store: LoggerStore, configuration: ConsoleConfiguration = .default, onDismiss: (() -> Void)?) {
        self.configuration = configuration
        
        self.consoleModel = ConsoleViewModel(store: store, configuration: configuration)
        self.consoleModel.onDismiss = onDismiss

        self.networkModel = ConsoleViewModel(store: store, configuration: configuration, contentType: .network)
        self.networkModel.onDismiss = onDismiss

        #if os(iOS) || os(macOS)
        self.pinsModel = ConsoleViewModel(store: store, configuration: configuration, contentType: .pins)
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
    static let network = MainViewModelItem(title: "Network", imageName: "icloud.and.arrow.down.fill")
    static let pins = MainViewModelItem(title: "Pins", imageName: "pin.fill")
    static let settings = MainViewModelItem(title: "Settings", imageName: "ellipsis.circle.fill")
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
                ConsoleView(model: consoleModel)
            }
        case .network:
            NavigationView {
                NetworkView(model: networkModel)
            }
        #if !os(tvOS)
        case .pins:
            NavigationView {
                PinsView(model: pinsModel)
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
