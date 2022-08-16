// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(tvOS)

public struct MainView: View {
    // TODO: replace with StateObject when available
    @State private var viewModel: MainViewModel

    @State private var isDefaultTabSelected = true
    @State private var viewController: UIViewController?

    /// - parameter onDismiss: pass onDismiss to add a close button.
    public init(store: LoggerStore = .shared, onDismiss: (() -> Void)? = nil) {
        _viewModel = State(wrappedValue: MainViewModel(store: store, onDismiss: onDismiss))
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
            .onDisappear { viewModel.freeMemory() }
        } else {
            tabView
                .onDisappear { viewModel.freeMemory() }
        }
        #else
        tabView
            .onDisappear { viewModel.freeMemory() }
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
