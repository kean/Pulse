// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#warning("TODO: howto present on tvOS? is there a close button?")

#if os(tvOS)

public struct MainView: View {
    // TODO: replace with StateObject
    let console: ConsoleViewModel
    let network: ConsoleViewModel
    let settings: SettingsViewModel

    /// - parameter onDismiss: pass onDismiss to add a close button.
    public init(store: LoggerStore = .shared) {
        self.console = ConsoleViewModel(store: store)
        self.network = ConsoleViewModel(store: store, mode: .network)
        self.settings = SettingsViewModel(store: store)
    }

    public var body: some View {
        NavigationView {
            TabView {
                ConsoleView(viewModel: console)
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Console")
                    }
                ConsoleView(viewModel: network)
                    .tabItem {
                        Image(systemName: "paperplane.fill")
                        Text("Network")
                    }
                SettingsView(viewModel: settings)
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            }
        }
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView(store: .mock)
    }
}
#endif

#endif
