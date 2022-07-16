// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(tvOS)

public struct MainView: View {
    let viewModel: MainViewModel

    /// - parameter onDismiss: pass onDismiss to add a close button.
    public init(store: LoggerStore = .default,
                configuration: ConsoleConfiguration = .default,
                onDismiss: (() -> Void)? = nil) {
        self.viewModel = MainViewModel(store: store, configuration: configuration, onDismiss: onDismiss)
    }

    public var body: some View {
        TabView {
            ForEach(viewModel.items) { item in
                NavigationView {
                    viewModel.makeView(for: item)
                }.tabItem {
                    Image(systemName: item.imageName)
                    Text(item.title)
                }
            }
        }
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            MainView(store: .mock)
            MainView(store: .mock)
                .environment(\.colorScheme, .dark)
        }
    }
}

#endif

#endif
