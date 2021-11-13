// The MIT License (MIT)
//
// Copyright (c) 2020–2021 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(tvOS)

@available(iOS 13.0, tvOS 14.0, *)
public struct MainView: View {
    let model: MainViewModel

    /// - parameter onDismiss: pass onDismiss to add a close button.
    public init(store: LoggerStore = .default,
                configuration: ConsoleConfiguration = .default,
                onDismiss: (() -> Void)? = nil) {
        self.model = MainViewModel(store: store, configuration: configuration, onDismiss: onDismiss)
    }

    public var body: some View {
        TabView {
            ForEach(model.items) { item in
                model.makeView(for: item)
                    .tabItem {
                        Image(systemName: item.imageName)
                        Text(item.title)
                    }
            }
        }
    }
}

#if DEBUG
@available(iOS 13.0, tvOS 14.0, *)
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
