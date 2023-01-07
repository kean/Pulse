// The MIT License (MIT)
//
// Copyright (c) 2020–2023 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(tvOS)

public struct MainView: View {
    @ObservedObject private var viewModel: MainViewModel // TODO: replace with StateObject

    /// - parameter onDismiss: pass onDismiss to add a close button.
    public init(store: LoggerStore = .shared) {
        viewModel = MainViewModel(store: store, onDismiss: nil)
    }

    public var body: some View {
        NavigationView {
            TabView {
                ForEach(viewModel.items) { item in
                    viewModel.makeView(for: item)
                        .tabItem {
                            Image(systemName: item.imageName)
                            Text(item.title)
                        }
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
