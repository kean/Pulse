// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

#if os(iOS) || os(tvOS)

public struct MainView: View {
    // TODO: replace with StateObject when available
    @State private var viewModel: MainViewModel

    @State private var isDefaultTabSelected = true
    @State private var viewController: UIViewController?

    /// - parameter onDismiss: pass onDismiss to add a close button.
    public init(store: LoggerStore = .default,
                configuration: ConsoleConfiguration = .default,
                onDismiss: (() -> Void)? = nil) {
        self.viewModel = MainViewModel(store: store, configuration: configuration, onDismiss: onDismiss)
    }

    public var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad, #available(iOS 14.0, *) {
            NavigationView {
                List(viewModel.items) { item in
                    if item.id == viewModel.items[0].id {
                        NavigationLink(isActive: $isDefaultTabSelected, destination: {
                            viewModel.makeView(for: item)
                        }) {
                            Image(systemName: item.imageName)
                                .foregroundColor(.accentColor)
                            Text(item.title)
                        }
                    } else {
                        NavigationLink(destination: {
                            viewModel.makeView(for: item)
                        }) {
                            Image(systemName: item.imageName)
                                .foregroundColor(.accentColor)
                            Text(item.title)
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationBarTitle("Menu")
                viewModel.makeView(for: viewModel.items[0])
                EmptyView()
            }
        } else {
            tabView
        }
        #else
        tabView
        #endif
    }

    @ViewBuilder
    private var tabView: some View {
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
        MainView(store: .mock)
    }
}

#endif

#endif
