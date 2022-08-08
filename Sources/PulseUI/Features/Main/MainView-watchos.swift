// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(watchOS)

public struct MainView: View {
    @StateObject private var viewModel: MainViewModel

    public init(store: LoggerStore = .shared) {
        self._viewModel = StateObject(wrappedValue: .init(store: store, onDismiss: nil))
    }

    public var body: some View {
       ConsoleView(viewModel: viewModel)
            .onDisappear { viewModel.freeMemory() }
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
